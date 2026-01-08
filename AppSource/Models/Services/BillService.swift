import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Error Types
enum BillCreationError: LocalizedError {
    case invalidUser
    case sessionNotReady
    case invalidData(String)
    case firestoreError(String)
    case participantNotFound
    case invalidAmount
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .invalidUser:
            return "User authentication is invalid"
        case .sessionNotReady:
            return "Session is not ready for bill creation"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .firestoreError(let message):
            return "Database error: \(message)"
        case .participantNotFound:
            return "Required participant not found"
        case .invalidAmount:
            return "Bill amount is invalid"
        case .authenticationRequired:
            return "User must be logged in to create bills"
        }
    }
}

enum BillUpdateError: LocalizedError {
    case billNotFound
    case unauthorizedUpdate
    case invalidData(String)
    case concurrentModification
    case firestoreError(String)
    case versionMismatch(localVersion: Int, serverVersion: Int)
    case operationTimeout
    case conflictDetected(conflict: BillConflict)
    
    var errorDescription: String? {
        switch self {
        case .billNotFound:
            return "Bill not found"
        case .unauthorizedUpdate:
            return "You don't have permission to update this bill"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .concurrentModification:
            return "Bill was modified by another user. Please refresh and try again."
        case .firestoreError(let message):
            return "Database error: \(message)"
        case .versionMismatch(let localVersion, let serverVersion):
            return "Version conflict: local version \(localVersion) vs server version \(serverVersion). Please refresh and try again."
        case .operationTimeout:
            return "Operation timed out. Please check your connection and try again."
        case .conflictDetected(let conflict):
            return "Conflict detected in fields: \(conflict.conflictingFields.joined(separator: ", ")). Manual resolution required."
        }
    }
}

enum BillDeleteError: LocalizedError {
    case billNotFound
    case unauthorizedDelete
    case firestoreError(String)
    
    var errorDescription: String? {
        switch self {
        case .billNotFound:
            return "Bill not found"
        case .unauthorizedDelete:
            return "You don't have permission to delete this bill"
        case .firestoreError(let message):
            return "Database error: \(message)"
        }
    }
}

// MARK: - Bill Service for Firebase Operations

/**
 # BillService

 Firestore CRUD Operations Manager for bill lifecycle management.

 ## Architecture Role
 - **Pattern:** Service Object (Business Logic Layer)
 - **Responsibility:** WRITE operations with validation, transactions, and notifications
 - **Lifecycle:** Created on-demand by SwiftUI views

 ## Key Responsibilities
 1. **Bill Lifecycle Operations:** Create, update, delete bills with atomic transactions
 2. **Data Validation:** Validate session data before writes (amount > 0, participants exist)
 3. **Optimistic Locking:** Version-based concurrency control to prevent data conflicts
 4. **Atomic Transactions:** Use `runTransaction()` for updates, `batch()` for creates
 5. **Notification Integration:** Trigger push notifications after successful operations

 ## Does NOT Handle
 - ❌ Real-time UI state management (use BillManager)
 - ❌ Setting up Firestore listeners (use BillManager)
 - ❌ Calculating user balances (use BillManager)
 - ❌ Managing user sessions (use AuthViewModel)

 ## Optimistic Locking Flow
 ```
 1. Read current bill from Firestore (within transaction)
 2. Check version matches expected version
 3. If mismatch → Detect conflicts via ConflictDetectionService
 4. If auto-resolvable → Apply merge strategy
 5. If not resolvable → Throw conflictDetected error
 6. If version matches → Update with incremented version
 ```

 ## Error Handling
 - Throws `BillCreationError` for create failures
 - Throws `BillUpdateError` for update failures (including conflicts)
 - Throws `BillDeleteError` for delete failures
 - All errors include descriptive messages for user display

 ## Performance Characteristics
 - **Bill creation:** ~200-500ms (network dependent)
 - **Transaction overhead:** ~100ms for optimistic locking
 - **Batch delete:** <1s for 10 bills
 - **Thread:** Background async tasks

 ## See Also
 - `BillManager` - For real-time reads and UI state
 - `ConflictDetectionService` - For conflict detection and resolution
 - `PushNotificationService` - For notification delivery
 - `architecture/bill-services-overview.md` - Service architecture
 */
final class BillService: ObservableObject {
    private let db = Firestore.firestore()
    private let pushNotificationService = PushNotificationService()

    /**
     Creates a new bill in Firestore with atomic batch operations.

     Validates session data, creates bill object with version=1, saves atomically,
     and triggers push notifications to all participants (except creator).

     - Parameters:
       - session: BillSplitSession containing bill data (items, participants, totals)
       - authViewModel: Authentication context for current user
       - contactsManager: Contact management for participant resolution

     - Returns: Created Bill object with Firestore-assigned ID

     - Throws:
       - `BillCreationError.authenticationRequired` - User not logged in
       - `BillCreationError.invalidData` - Bill has no items
       - `BillCreationError.invalidAmount` - Total amount ≤ 0
       - `BillCreationError.participantNotFound` - Payer not in participant list
       - `BillCreationError.firestoreError` - Database save failed

     ## Validation Checks
     1. User must be authenticated
     2. Session must have ≥1 item
     3. Total amount > 0
     4. Payer must exist in participant list

     ## Side Effects
     - Saves bill to `bills` collection
     - Updates participant activity timestamps
     - Sends push notifications (async, non-blocking)

     ## Usage
     ```swift
     let bill = try await billService.createBill(
         from: session,
         authViewModel: authViewModel,
         contactsManager: contactsManager
     )
     ```
     */
    func createBill(from session: BillSplitSession, authViewModel: AuthViewModel, contactsManager: ContactsManager) async throws -> Bill {
        guard let currentUser = authViewModel.currentUser else {
            throw BillCreationError.authenticationRequired
        }
        
        // Validate session data
        guard !session.items.isEmpty else {
            throw BillCreationError.invalidData("Bill must have at least one item")
        }
        
        guard session.totalAmount > 0 else {
            throw BillCreationError.invalidAmount
        }
        
        guard let paidByParticipant = session.participants.first(where: { $0.id == session.paidBy }) else {
            throw BillCreationError.participantNotFound
        }
        
        // Create bill with initial version
        let bill = Bill(
            createdBy: currentUser.uid,
            createdByDisplayName: currentUser.displayName ?? "Unknown",
            createdByEmail: currentUser.email ?? "unknown@example.com",
            paidBy: session.paidBy,
            paidByDisplayName: paidByParticipant.displayName,
            paidByEmail: paidByParticipant.email,
            billName: session.billName,
            totalAmount: session.totalAmount,
            currency: session.currency,
            items: session.items,
            participants: session.participants,
            calculatedTotals: session.calculatedTotals,
            roundingAdjustments: session.roundingAdjustments,
            version: 1,
            operationId: UUID().uuidString
        )
        
        try await saveBillToFirestore(bill: bill)
        
        // Send push notifications to other participants (Epic 2: US-SYNC-004)
        await pushNotificationService.notifyBillCreated(
            bill: bill,
            creatorName: currentUser.displayName ?? "Unknown",
            excludeUserId: currentUser.uid
        )
        
        return bill
    }

    /**
     Updates an existing bill with new data using optimistic locking.

     Uses Firestore transactions with version checking to prevent concurrent modification
     conflicts. If version mismatch detected, attempts auto-resolution via
     ConflictDetectionService or throws error for manual resolution.

     - Parameters:
       - billId: Firestore document ID of bill to update
       - session: BillSplitSession with updated bill data
       - currentUserId: Firebase UID of user making the update
       - authViewModel: Authentication context
       - contactsManager: Contact management

     - Throws:
       - `BillUpdateError.unauthorizedUpdate` - User not logged in or not bill creator
       - `BillUpdateError.billNotFound` - Bill doesn't exist in Firestore
       - `BillUpdateError.invalidData` - Bill data decode failed
       - `BillUpdateError.versionMismatch` - Concurrent modification detected
       - `BillUpdateError.conflictDetected` - Unresolvable conflict (manual resolution needed)
       - `BillUpdateError.firestoreError` - Database update failed

     ## Optimistic Locking Process
     1. Start Firestore transaction
     2. Read current bill from server
     3. Validate user is authorized (createdBy == currentUserId)
     4. Check version: `session.expectedVersion == billData.version`
     5. If mismatch:
        - Detect conflicts with ConflictDetectionService
        - Try auto-resolution for low-severity conflicts
        - Throw error if auto-resolution not possible
     6. If version matches:
        - Update bill with `version + 1`
        - Commit transaction atomically

     ## Conflict Resolution Strategy
     - **Auto-resolvable:** Metadata only (bill name, currency)
     - **Requires manual resolution:** Financial fields, items, participants

     ## Side Effects
     - Updates bill document in Firestore (atomic)
     - Sends push notifications to participants (async)

     ## Usage
     ```swift
     try await billService.updateBill(
         billId: bill.id,
         session: session,
         currentUserId: user.uid,
         authViewModel: authViewModel,
         contactsManager: contactsManager
     )
     ```

     - Important: Caller must handle `BillUpdateError.conflictDetected` by fetching
                  latest bill and showing conflict resolution UI to user.
     */
    func updateBill(billId: String, session: BillSplitSession, currentUserId: String, authViewModel: AuthViewModel, contactsManager: ContactsManager) async throws {
        guard let currentUser = authViewModel.currentUser else {
            throw BillUpdateError.unauthorizedUpdate
        }
        
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let billRef = self.db.collection("bills").document(billId)
            let billSnapshot: DocumentSnapshot
            
            do {
                billSnapshot = try transaction.getDocument(billRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "BillService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch bill"])
                return nil
            }
            
            guard billSnapshot.exists else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bill not found"])
                return nil
            }
            
            guard let billData = try? billSnapshot.data(as: Bill.self) else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid bill data"])
                return nil
            }
            
            // Check authorization
            guard billData.createdBy == currentUserId else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unauthorized update"])
                return nil
            }
            
            // Check version for optimistic locking with detailed conflict detection
            if let expectedVersion = session.expectedVersion, billData.version != expectedVersion {
                // Create local bill representation from session
                let localBill = Bill(
                    id: billData.id,
                    createdBy: billData.createdBy,
                    createdByDisplayName: billData.createdByDisplayName,
                    createdByEmail: billData.createdByEmail,
                    paidBy: session.paidBy,
                    paidByDisplayName: session.participants.first(where: { $0.id == session.paidBy })?.displayName ?? billData.paidByDisplayName,
                    paidByEmail: session.participants.first(where: { $0.id == session.paidBy })?.email ?? billData.paidByEmail,
                    billName: session.billName,
                    totalAmount: session.totalAmount,
                    currency: session.currency,
                    date: billData.date,
                    createdAt: billData.createdAt,
                    items: session.items,
                    participants: session.participants,
                    calculatedTotals: session.calculatedTotals,
                    roundingAdjustments: session.roundingAdjustments,
                    isDeleted: billData.isDeleted,
                    version: expectedVersion,
                    operationId: UUID().uuidString
                )
                
                // Detect detailed conflicts
                let operationId = UUID().uuidString
                if let conflict = ConflictDetectionService.detectConflicts(
                    localBill: localBill,
                    serverBill: billData,
                    operationId: operationId
                ) {
                    // Try auto-resolution for compatible conflicts
                    if ConflictDetectionService.canAutoResolve(conflict: conflict),
                       let resolvedBill = ConflictDetectionService.autoResolveConflict(
                        localBill: localBill,
                        serverBill: billData,
                        conflict: conflict
                       ) {
                        // Use auto-resolved bill
                        try? transaction.setData(from: resolvedBill, forDocument: billRef)
                        return nil
                    }
                    
                    // Manual resolution required
                    errorPointer?.pointee = NSError(domain: "BillService", code: 5, userInfo: [
                        NSLocalizedDescriptionKey: "Conflict detected: \(conflict.conflictingFields.joined(separator: ", "))",
                        "conflict": conflict
                    ])
                    return nil
                }
            }
            
            // Create updated bill
            let updatedBill = Bill(
                id: billData.id,
                createdBy: billData.createdBy,
                createdByDisplayName: billData.createdByDisplayName,
                createdByEmail: billData.createdByEmail,
                paidBy: session.paidBy,
                paidByDisplayName: session.participants.first(where: { $0.id == session.paidBy })?.displayName ?? billData.paidByDisplayName,
                paidByEmail: session.participants.first(where: { $0.id == session.paidBy })?.email ?? billData.paidByEmail,
                billName: session.billName,
                totalAmount: session.totalAmount,
                currency: session.currency,
                date: billData.date,
                createdAt: billData.createdAt,
                items: session.items,
                participants: session.participants,
                calculatedTotals: session.calculatedTotals,
                roundingAdjustments: session.roundingAdjustments,
                isDeleted: billData.isDeleted,
                version: billData.version + 1, // Increment version
                operationId: UUID().uuidString
            )
            
            // Update with incremented version
            try? transaction.setData(from: updatedBill, forDocument: billRef)
            return updatedBill // Return updated bill for notification
        })
        
        // Send push notifications to other participants after successful update (Epic 2: US-SYNC-005)
        if let currentUser = authViewModel.currentUser {
            // Create temporary bill object for notification
            let notificationBill = Bill(
                id: billId,
                createdBy: currentUserId,
                createdByDisplayName: currentUser.displayName ?? "Unknown",
                createdByEmail: currentUser.email ?? "unknown@example.com",
                paidBy: session.paidBy,
                paidByDisplayName: session.participants.first(where: { $0.id == session.paidBy })?.displayName ?? "Unknown",
                paidByEmail: session.participants.first(where: { $0.id == session.paidBy })?.email ?? "unknown@example.com",
                billName: session.billName,
                totalAmount: session.totalAmount,
                currency: session.currency,
                date: Date(),
                createdAt: Date(),
                items: session.items,
                participants: session.participants,
                calculatedTotals: session.calculatedTotals,
                roundingAdjustments: session.roundingAdjustments,
                isDeleted: false,
                version: 1,
                operationId: UUID().uuidString
            )
            
            await pushNotificationService.notifyBillEdited(
                bill: notificationBill,
                editorName: currentUser.displayName ?? "Unknown",
                excludeUserId: currentUserId
            )
        }
    }

    /**
     Deletes a bill from Firestore using soft deletion.

     Sets `isDeleted = true` flag instead of physically removing document.
     Soft deletion allows:
     - Preserving bill history for auditing
     - Recovering accidentally deleted bills
     - Maintaining referential integrity

     - Parameters:
       - billId: Firestore document ID of bill to delete
       - currentUserId: Firebase UID of user requesting deletion

     - Throws:
       - `BillDeleteError.billNotFound` - Bill doesn't exist
       - `BillDeleteError.unauthorizedDelete` - User is not bill creator
       - `BillDeleteError.firestoreError` - Database update failed

     ## Authorization
     - Only bill creator (`createdBy == currentUserId`) can delete
     - Prevents participants from deleting bills they didn't create

     ## Soft Deletion Process
     1. Start Firestore transaction
     2. Read current bill
     3. Validate user is creator
     4. Set `isDeleted = true` and increment `version`
     5. Commit transaction

     ## Side Effects
     - Updates bill document with `isDeleted = true`
     - BillManager listeners automatically remove bill from UI
     - Sends push notifications to participants (async)

     ## Usage
     ```swift
     try await billService.deleteBill(
         billId: bill.id,
         currentUserId: user.uid
     )
     ```

     - Note: Deleted bills are filtered server-side in BillManager queries via
             `whereField("isDeleted", isEqualTo: false)` for security.
     */
    func deleteBill(billId: String, currentUserId: String) async throws {
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let billRef = self.db.collection("bills").document(billId)
            let billSnapshot: DocumentSnapshot
            
            do {
                billSnapshot = try transaction.getDocument(billRef)
            } catch {
                errorPointer?.pointee = NSError(domain: "BillService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch bill"])
                return nil
            }
            
            guard billSnapshot.exists else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Bill not found"])
                return nil
            }
            
            guard let billData = try? billSnapshot.data(as: Bill.self) else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid bill data"])
                return nil
            }
            
            // Check authorization - only creator can delete
            guard billData.createdBy == currentUserId else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unauthorized delete"])
                return nil
            }
            
            // Fetch deleter info for metadata
            guard let currentUserDoc = try? transaction.getDocument(self.db.collection("users").document(currentUserId)),
                  let userData = currentUserDoc.data(),
                  let deleterName = userData["displayName"] as? String else {
                errorPointer?.pointee = NSError(domain: "BillService", code: 5, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch deleter info"])
                return nil
            }

            // Soft delete by setting isDeleted flag, deletion metadata, and incrementing version
            var updatedBill = billData
            updatedBill.isDeleted = true
            updatedBill.deletedBy = currentUserId
            updatedBill.deletedByDisplayName = deleterName
            updatedBill.deletedAt = Timestamp()
            updatedBill.version += 1
            updatedBill.operationId = UUID().uuidString

            try? transaction.setData(from: updatedBill, forDocument: billRef)
            return updatedBill // Return updated bill for notification
        })

        // Send push notifications to other participants after successful deletion (Epic 2: US-SYNC-006)
        // We need to get the updated bill data to send notifications
        do {
            let billSnapshot = try await db.collection("bills").document(billId).getDocument()

            guard let deletedBill = try? billSnapshot.data(as: Bill.self) else {
                throw NSError(domain: "BillService", code: 6, userInfo: [NSLocalizedDescriptionKey: "Failed to decode deleted bill"])
            }

            guard let currentUserDoc = try? await db.collection("users").document(currentUserId).getDocument(),
                  let userData = currentUserDoc.data() else {
                throw NSError(domain: "BillService", code: 7, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch user data"])
            }

            let deleterName = deletedBill.deletedByDisplayName ?? userData["displayName"] as? String ?? "Unknown"
            let deleterEmail = userData["email"] as? String ?? "unknown@example.com"

            // Create deletion activity for all participants
            let activityId = UUID().uuidString
            let activity = BillActivity(
                id: activityId,
                billId: billId,
                billName: deletedBill.billName ?? "Unnamed Bill",
                activityType: .deleted,
                actorName: deleterName,
                actorEmail: deleterEmail,
                participantEmails: deletedBill.participants.map { $0.email },
                timestamp: Date(),
                amount: deletedBill.totalAmount,
                currency: deletedBill.currency ?? "USD"
            )

            // Save deletion activity for all participants
            let batch = db.batch()
            for (index, participantId) in deletedBill.participantIds.enumerated() {
                let activityRef = db.collection("users")
                    .document(participantId)
                    .collection("billActivities")
                    .document(activityId)

                do {
                    try batch.setData(from: activity, forDocument: activityRef)
                } catch {
                }
            }

            try await batch.commit()

            await pushNotificationService.notifyBillDeleted(
                bill: deletedBill,
                deleterName: deleterName,
                excludeUserId: currentUserId
            )
        } catch {
            // Re-throw to ensure caller knows deletion activity failed
            throw error
        }
    }

    /**
     Convenience overload for deleteBill that accepts BillManager.
     Delegates to the main deleteBill implementation.
     */
    func deleteBill(billId: String, currentUserId: String, billManager: BillManager) async throws {
        try await deleteBill(billId: billId, currentUserId: currentUserId)
    }

    // MARK: - Development Only Methods

    /**
     Deletes ALL bills where the user is a participant (DEVELOPMENT ONLY).

     This method should only be used for:
     - Clearing test data during development
     - Resetting the database between testing sessions
     - Debugging bill management features

     - Parameter currentUserId: The user's Firebase UID

     - Warning: This permanently deletes all bills. Use with extreme caution.
               Only enabled in DEBUG builds.
     */
    func deleteAllUserBills(currentUserId: String) async throws {
        #if DEBUG
        // Fetch all bills where user is participant
        let snapshot = try await db.collection("bills")
            .whereField("participantIds", arrayContains: currentUserId)
            .getDocuments()

        guard !snapshot.documents.isEmpty else {
            print("🗑️ No bills to delete for user \(currentUserId)")
            return
        }

        print("🗑️ [DEV] Deleting \(snapshot.documents.count) bills for user \(currentUserId)")

        // Use batch for atomic deletion
        let batch = db.batch()

        for document in snapshot.documents {
            let billRef = db.collection("bills").document(document.documentID)

            // Soft delete by setting isDeleted flag
            batch.updateData([
                "isDeleted": true,
                "deletedAt": FieldValue.serverTimestamp(),
                "deletedBy": currentUserId
            ], forDocument: billRef)
        }

        // Commit batch deletion
        try await batch.commit()

        print("✅ [DEV] Successfully deleted \(snapshot.documents.count) bills")
        #else
        throw BillDeleteError.unauthorizedDelete
        #endif
    }

    // MARK: - Private Helper Methods

    /**
     Saves bill to Firestore using atomic batch operations.

     Uses Firestore batch writes to ensure all-or-nothing persistence:
     - Bill document creation
     - Participant activity timestamp updates

     - Parameter bill: Bill object to save

     - Throws: `BillCreationError.firestoreError` if batch commit fails

     ## Atomicity Guarantee
     - If any operation in batch fails, entire batch is rolled back
     - Prevents partial writes and data inconsistency

     ## Batch Operations
     1. Add bill document to `bills` collection
     2. Update `participants` collection activity timestamps
     3. Commit batch atomically

     - Important: Private helper used only by `createBill()`.
                  Never call directly from UI layer.
     */
    private func saveBillToFirestore(bill: Bill) async throws {
        let batch = db.batch()
        
        // Add bill document
        let billRef = db.collection("bills").document(bill.id)
        try batch.setData(from: bill, forDocument: billRef)
        
        // Update participant balances (for caching/aggregation)
        for participant in bill.participants {
            let participantRef = db.collection("participants").document(participant.id)
            batch.updateData([
                "lastActivity": Timestamp(),
                "isActive": true
            ], forDocument: participantRef)
        }
        
        // Commit batch atomically
        try await batch.commit()
    }
    
    /// Updates bill in Firestore using atomic operations
    private func updateBillInFirestore(bill: Bill) async throws {
        let batch = db.batch()
        
        // Update bill document
        let billRef = db.collection("bills").document(bill.id)
        try batch.setData(from: bill, forDocument: billRef)
        
        // Update participant activity timestamps
        for participant in bill.participants {
            let participantRef = db.collection("participants").document(participant.id)
            batch.updateData([
                "lastActivity": Timestamp(),
                "isActive": true
            ], forDocument: participantRef)
        }
        
        // Commit batch atomically
        try await batch.commit()
    }

    /**
     Updates an existing bill with new values and creates edit activity for all participants.

     This method is used by BillEditView to save changes to an existing bill.

     - Parameters:
       - billId: Firestore document ID of the bill to update
       - billName: New bill name
       - items: Updated list of bill items
       - participants: Updated list of participants
       - paidByParticipantId: ID of the participant who paid
       - currentUserId: Firebase Auth UID of user making the edit
       - billManager: BillManager instance to trigger UI refresh

     - Throws: BillServiceError if update fails or user is not authorized

     ## Features:
     - Permission check: Only bill creator can edit
     - Recalculates debt amounts based on new items
     - Creates "edited" activity for all participants
     - Updates bill in Firestore atomically
     - Triggers real-time UI refresh via BillManager
     */
    func updateBill(
        billId: String,
        billName: String,
        items: [BillItem],
        participants: [BillParticipant],
        paidByParticipantId: String,
        currentUserId: String,
        currentUserEmail: String,
        billManager: BillManager
    ) async throws {
        // Fetch current bill
        let billRef = db.collection("bills").document(billId)
        let billSnapshot = try await billRef.getDocument()

        guard var bill = try? billSnapshot.data(as: Bill.self) else {
            throw BillDeleteError.billNotFound
        }

        // Permission check: Only creator can edit
        guard bill.createdBy == currentUserId else {
            throw BillDeleteError.notAuthorized
        }

        // Update bill properties
        bill.billName = billName
        bill.items = items
        bill.participants = participants
        bill.paidBy = paidByParticipantId

        // Note: totalAmount is derived from items sum and doesn't need manual update
        // Recalculate debt totals based on new items
        bill.calculatedTotals = BillCalculator.calculateOwedAmounts(bill: bill)

        // Update bill in Firestore
        try await updateBillInFirestore(bill: bill)

        // Create "edited" activity for all participants
        let editorName = participants.first(where: { $0.id == currentUserId })?.displayName ?? "Someone"
        // CRITICAL: Use current authenticated email, not bill snapshot email, for Firestore security rules
        let editorEmail = currentUserEmail

        // Calculate new total from updated items
        let newTotalAmount = items.reduce(0.0) { $0 + $1.price }

        AppLog.debug("Creating edit activity - Editor: \(editorEmail), Participants: \(participants.map { $0.email })", category: .billManagement)

        let activityId = UUID().uuidString
        let activity = BillActivity(
            id: activityId,
            billId: billId,
            billName: billName,
            activityType: .edited,
            actorName: editorName,
            actorEmail: editorEmail,
            participantEmails: participants.map { $0.email },
            timestamp: Date(),
            amount: newTotalAmount,
            currency: bill.currency ?? "USD"
        )

        // Save edit activity for all participants
        let batch = db.batch()
        for participantId in bill.participantIds {
            let activityRef = db.collection("users")
                .document(participantId)
                .collection("billActivities")
                .document(activityId)

            do {
                try batch.setData(from: activity, forDocument: activityRef)
            } catch {
                AppLog.billError("Failed to add activity to batch for participant \(participantId)", error: error)
            }
        }

        do {
            try await batch.commit()
            AppLog.billSuccess("Edit activity saved for \(bill.participantIds.count) participants", billId: billId)
        } catch {
            AppLog.billError("Failed to commit edit activity batch", error: error)
            throw error
        }

        // Refresh BillManager to update UI
        await billManager.refreshBills()
    }
}

// MARK: - Temporary Note
/*
 This file contains the structure for BillService extracted from DataModels.swift.
 The actual implementation is temporarily left in the original file to avoid breaking changes.
 Once all files are created, we'll move the implementations in phases.
 */
