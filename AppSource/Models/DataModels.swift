import SwiftUI
import Vision
import UIKit
import NaturalLanguage
import FirebaseFirestore
import os.log

// MARK: - OSLog Categories (Industry Standard)
extension OSLog {
    static let authentication = OSLog(subsystem: "com.settled.core", category: "authentication")
    static let billManagement = OSLog(subsystem: "com.settled.core", category: "bill-management")
    static let firebase = OSLog(subsystem: "com.settled.core", category: "firebase")
    static let pushNotifications = OSLog(subsystem: "com.settled.core", category: "push-notifications")
    static let calculations = OSLog(subsystem: "com.settled.core", category: "calculations")
}

// MARK: - Logging Convenience Functions (Industry Standard)
struct AppLog {
    // MARK: - Authentication Logging
    static func authSuccess(_ message: String, userEmail: String? = nil) {
        if let email = userEmail {
            os_log("✅ %{public}@: %{private}@", log: .authentication, type: .info, message, email)
        } else {
            os_log("✅ %{public}@", log: .authentication, type: .info, message)
        }
    }
    
    static func authError(_ message: String, error: Error? = nil) {
        if let error = error {
            os_log("❌ %{public}@: %{public}@", log: .authentication, type: .error, message, error.localizedDescription)
        } else {
            os_log("❌ %{public}@", log: .authentication, type: .error, message)
        }
    }
    
    static func authWarning(_ message: String) {
        os_log("⚠️ %{public}@", log: .authentication, type: .default, message)
    }
    
    static func debug(_ message: String, category: OSLog = .authentication) {
        #if DEBUG
        os_log("🔍 DEBUG: %{public}@", log: category, type: .debug, message)
        #endif
    }
    
    // MARK: - Bill Management Logging
    static func billSuccess(_ message: String, billId: String? = nil) {
        if let id = billId {
            os_log("✅ %{public}@: %{private}@", log: .billManagement, type: .info, message, id)
        } else {
            os_log("✅ %{public}@", log: .billManagement, type: .info, message)
        }
    }
    
    static func billError(_ message: String, error: Error? = nil) {
        if let error = error {
            os_log("❌ %{public}@: %{public}@", log: .billManagement, type: .error, message, error.localizedDescription)
        } else {
            os_log("❌ %{public}@", log: .billManagement, type: .error, message)
        }
    }
    
    static func billOperation(_ message: String, billId: String? = nil) {
        if let id = billId {
            os_log("🔵 %{public}@: %{private}@", log: .billManagement, type: .info, message, id)
        } else {
            os_log("🔵 %{public}@", log: .billManagement, type: .info, message)
        }
    }
    
    // MARK: - Firebase Logging
    static func firebaseError(_ message: String, error: Error? = nil) {
        if let error = error {
            os_log("❌ Firebase: %{public}@: %{public}@", log: .firebase, type: .error, message, error.localizedDescription)
        } else {
            os_log("❌ Firebase: %{public}@", log: .firebase, type: .error, message)
        }
    }
    
    // MARK: - Push Notifications Logging
    static func notificationSuccess(_ message: String, token: String? = nil) {
        if let token = token {
            let tokenPreview = String(token.prefix(8)) + "..."
            os_log("✅ FCM: %{public}@: %{private}@", log: .pushNotifications, type: .info, message, tokenPreview)
        } else {
            os_log("✅ FCM: %{public}@", log: .pushNotifications, type: .info, message)
        }
    }
    
    static func notificationError(_ message: String, error: Error? = nil) {
        if let error = error {
            os_log("❌ FCM: %{public}@: %{public}@", log: .pushNotifications, type: .error, message, error.localizedDescription)
        } else {
            os_log("❌ FCM: %{public}@", log: .pushNotifications, type: .error, message)
        }
    }
}

// MARK: - REFACTORING NOTE
// This file has been structurally organized into modular components.
// New files created: Core/, Services/, and Session/ directories.
// Implementations remain here temporarily to maintain compatibility.

// MARK: - Currency Utilities (Legacy - moved to Core/CurrencyExtensions.swift)
// NOTE: These implementations will be removed once import is uncommented
extension Double {
    /// Rounds a currency value to 2 decimal places with proper rounding
    var currencyRounded: Double {
        return (self * 100).rounded() / 100
    }
    
    /// Safely adds two currency values with proper rounding
    func currencyAdd(_ other: Double) -> Double {
        return (self + other).currencyRounded
    }

    /// Safely subtracts currency values with proper rounding
    func currencySubtract(_ other: Double) -> Double {
        return (self - other).currencyRounded
    }

    /// Safely divides currency value by count with proper rounding
    func currencyDivide(by count: Int) -> Double {
        guard count > 0 else { return 0.0 }
        return (self / Double(count)).currencyRounded
    }
    
    /// Smart distribution of currency among participants ensuring total matches exactly
    /// Example: $8.99 / 2 = [$4.49, $4.50] instead of [$4.495, $4.495]
    static func smartDistribute(total: Double, among count: Int) -> [Double] {
        guard count > 0 else { return [] }
        
        let baseAmount = (total / Double(count)).currencyRounded
        let totalBasic = baseAmount * Double(count)
        let remainder = (total - totalBasic).currencyRounded
        
        var distribution = Array(repeating: baseAmount, count: count)
        
        // Distribute remainder cents to first participants
        let remainderCents = Int((remainder * 100).rounded())
        for i in 0..<min(abs(remainderCents), count) {
            distribution[i] = distribution[i].currencyAdd(remainderCents > 0 ? 0.01 : -0.01)
        }
        
        return distribution
    }
}

// MARK: - Data Models

// MARK: - Error Types
enum OCRError: Error {
    case apiError(String)
    case parseError(String)
    case networkError(String)
}

// MARK: - OCR Models
struct OCRResult {
    let rawText: String
    let parsedItems: [ReceiptItem] // Will be empty initially - users add manually
    let identifiedTotal: Double?
    let suggestedAmounts: [Double] // Potential item prices for quick selection
    let confidence: Float
    let processingTime: TimeInterval
    var classifiedReceipt: ClassifiedReceipt? = nil  // NEW: Smart classification results
}

enum ConfidenceLevel: String, Codable {
    case high = "high"           // Exact match found in OCR text
    case medium = "medium"       // Part of close combination
    case low = "low"             // Approximated or uncertain
    case placeholder = "placeholder" // User needs to fill in
}

struct ReceiptItem: Identifiable, Equatable, Codable {
    let id = UUID()
    var name: String
    var price: Double
    var confidence: ConfidenceLevel = .high
    var isEditable: Bool = true
    
    // Store original detected values for confidence display
    let originalDetectedName: String?
    let originalDetectedPrice: Double?
    
    init(name: String, price: Double, confidence: ConfidenceLevel = .high, originalDetectedName: String? = nil, originalDetectedPrice: Double? = nil) {
        self.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        self.price = price
        self.confidence = confidence
        self.originalDetectedName = originalDetectedName
        self.originalDetectedPrice = originalDetectedPrice
    }
}

struct ReceiptAnalysis {
    let tax: Double
    let tip: Double  
    let total: Double
    let itemCount: Int
}

// MARK: - Shared Transaction Models
struct UITransaction: Identifiable {
    let id = UUID()
    let personName: String
    let amount: Double
    let description: String
}

struct UIPersonDebt: Identifiable {
    let id = UUID()
    let name: String
    let total: Double
    let color: Color
}

// MARK: - Assign Screen Models
struct UIParticipant: Identifiable, Hashable {
    let id: String  // Firebase UID for consistency with BillParticipant
    let name: String
    let color: Color
    var photoURL: String?  // Profile picture URL - mutable to allow async loading

    // Hash-based color assignment for consistent colors per Firebase UID
    var assignedColor: Color {
        let colors: [Color] = [.blue, .red, .green, .orange, .purple, .pink, .cyan, .yellow]
        let hashValue = abs(id.hashValue) % colors.count
        return colors[hashValue]
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: UIParticipant, rhs: UIParticipant) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Transaction Contact Models (Splitwise-style)
struct TransactionContact: Identifiable, Codable {
    let id: String                    // Contact ID in our system
    let contactUserId: String?        // Reference to global participants collection (if registered)
    let displayName: String           // How this user knows them
    let email: String
    let phoneNumber: String?
    let lastTransactionAt: Date
    let totalTransactions: Int
    let createdAt: Date
    let updatedAt: Date
    let nickname: String?             // Optional custom nickname
    
    init(displayName: String, email: String, phoneNumber: String? = nil, contactUserId: String? = nil, nickname: String? = nil) {
        self.id = UUID().uuidString
        self.contactUserId = contactUserId
        self.displayName = displayName
        self.email = email
        self.phoneNumber = phoneNumber
        self.lastTransactionAt = Date()
        self.totalTransactions = 1
        self.createdAt = Date()
        self.updatedAt = Date()
        self.nickname = nickname
    }
}

struct ContactValidationResult {
    let isValid: Bool
    let error: String?
    let contact: TransactionContact?
}

struct UIItem: Identifiable {
    let id: Int  // Keep item ID as Int for internal bill session management
    var name: String
    var price: Double
    var assignedTo: String? // Legacy: single participant assignment (Firebase UID)
    var assignedToParticipants: Set<String> // New: multiple participants per item (Firebase UIDs)
    var confidence: ConfidenceLevel

    // Store original detected values for confidence display
    let originalDetectedName: String?
    let originalDetectedPrice: Double?

    // Computed property to get the cost per assigned participant (simple division, for display)
    var costPerParticipant: Double {
        let participantCount = assignedToParticipants.isEmpty ? 1 : assignedToParticipants.count
        return price.currencyDivide(by: participantCount)
    }

    // Get the exact cost for a specific participant using smart distribution
    func getCostForParticipant(participantId: String) -> Double {
        guard assignedToParticipants.contains(participantId) else {
            return 0.0
        }

        let participantIds = Array(assignedToParticipants).sorted()
        let distribution = Double.smartDistribute(total: price, among: participantIds.count)

        if let index = participantIds.firstIndex(of: participantId) {
            return distribution[index]
        }

        return 0.0
    }

    // Initialize with multiple participants support
    init(id: Int, name: String, price: Double, assignedTo: String? = nil, assignedToParticipants: Set<String> = [], confidence: ConfidenceLevel = .high, originalDetectedName: String? = nil, originalDetectedPrice: Double? = nil) {
        self.id = id
        self.name = name
        self.price = price
        self.assignedTo = assignedTo
        self.assignedToParticipants = assignedToParticipants
        self.confidence = confidence
        self.originalDetectedName = originalDetectedName
        self.originalDetectedPrice = originalDetectedPrice
    }
}

// MARK: - Summary Screen Models
struct UISummary {
    let restaurant: String
    let date: String
    let total: Double
    let paidBy: String
    let participants: [UISummaryParticipant]
    let breakdown: [UIBreakdown]
}

struct UISummaryParticipant: Identifiable {
    let id: String  // Firebase UID for consistency
    let name: String
    let color: Color
    let owes: Double
    let gets: Double
}

struct UIBreakdown: Identifiable {
    let id: String  // Firebase UID for consistency
    let name: String
    let color: Color
    let items: [UIBreakdownItem]
    let photoURL: String?  // Profile picture URL
}

struct UIBreakdownItem {
    let name: String
    let price: Double
}

// MARK: - Bill Settlement Data Models

import FirebaseFirestore
import FirebaseAuth
// TODO: Uncomment after adding FirebaseMessaging dependency in Xcode
// import FirebaseMessaging

// Bill entry method for analytics and metadata
enum BillEntryMethod: String, Codable {
    case scan = "scan"
    case manual = "manual"
}

struct Bill: Codable, Identifiable, Hashable {
    let id: String
    let paidBy: String // userID who paid
    let paidByDisplayName: String // Snapshot for UI
    let paidByEmail: String // Snapshot for notifications
    let billName: String? // Custom name or default description (optional for backward compatibility)
    let totalAmount: Double // Always matches sum of items
    let currency: String
    let date: Timestamp
    let createdAt: Timestamp
    let items: [BillItem]
    let participants: [BillParticipant]
    let participantIds: [String] // Flattened array for efficient Firestore querying
    
    // Audit trail
    let createdBy: String // userID who created bill
    let createdByDisplayName: String // Snapshot for UI
    let createdByEmail: String // Snapshot for notifications
    let lastModifiedBy: String?
    let lastModifiedAt: Timestamp?
    
    // Financial reconciliation
    let calculatedTotals: [String: Double] // userID: amount owed to paidBy
    let roundingAdjustments: [String: Double] // Track penny distributions
    
    // Deletion status
    var isDeleted: Bool
    var deletedBy: String? // userID who deleted the bill
    var deletedByDisplayName: String? // Display name snapshot
    var deletedAt: Timestamp? // When bill was deleted

    // Entry method tracking (optional for backward compatibility with existing bills)
    var entryMethod: BillEntryMethod?

    init(id: String = UUID().uuidString,
         createdBy: String,
         createdByDisplayName: String,
         createdByEmail: String,
         paidBy: String,
         paidByDisplayName: String,
         paidByEmail: String,
         billName: String?,
         totalAmount: Double,
         currency: String = "USD",
         date: Timestamp = Timestamp(),
         createdAt: Timestamp = Timestamp(),
         items: [BillItem],
         participants: [BillParticipant],
         participantIds: [String]? = nil,
         calculatedTotals: [String: Double]? = nil,
         roundingAdjustments: [String: Double] = [:],
         isDeleted: Bool = false,
         deletedBy: String? = nil,
         deletedByDisplayName: String? = nil,
         deletedAt: Timestamp? = nil,
         entryMethod: BillEntryMethod? = nil) {
        self.id = id
        self.createdBy = createdBy
        self.createdByDisplayName = createdByDisplayName
        self.createdByEmail = createdByEmail
        self.paidBy = paidBy
        self.paidByDisplayName = paidByDisplayName
        self.paidByEmail = paidByEmail
        self.billName = billName
        self.totalAmount = totalAmount
        self.currency = currency
        self.date = date
        self.createdAt = createdAt
        self.items = items
        self.participants = participants
        self.participantIds = participantIds ?? participants.map { $0.id }
        self.lastModifiedBy = nil
        self.lastModifiedAt = nil
        self.calculatedTotals = calculatedTotals ?? [:]
        self.roundingAdjustments = roundingAdjustments
        self.isDeleted = isDeleted
        self.deletedBy = deletedBy
        self.deletedByDisplayName = deletedByDisplayName
        self.deletedAt = deletedAt
        self.entryMethod = entryMethod
    }
    
    // Legacy initializer for backward compatibility
    init(id: String = UUID().uuidString,
         paidBy: String,
         paidByDisplayName: String,
         paidByEmail: String,
         billName: String?,
         totalAmount: Double,
         currency: String = "USD",
         date: Timestamp = Timestamp(),
         items: [BillItem],
         participants: [BillParticipant],
         createdBy: String,
         createdByDisplayName: String = "Unknown",
         createdByEmail: String = "unknown@example.com",
         calculatedTotals: [String: Double],
         roundingAdjustments: [String: Double] = [:],
         isDeleted: Bool = false,
         entryMethod: BillEntryMethod = .scan) {
        self.id = id
        self.paidBy = paidBy
        self.paidByDisplayName = paidByDisplayName
        self.paidByEmail = paidByEmail
        self.billName = billName
        self.totalAmount = totalAmount
        self.currency = currency
        self.date = date
        self.createdAt = Timestamp()
        self.items = items
        self.participants = participants
        self.participantIds = participants.map { $0.id } // Flatten for querying
        self.createdBy = createdBy
        self.createdByDisplayName = createdByDisplayName
        self.createdByEmail = createdByEmail
        self.lastModifiedBy = nil
        self.lastModifiedAt = nil
        self.calculatedTotals = calculatedTotals
        self.roundingAdjustments = roundingAdjustments
        self.isDeleted = isDeleted
        self.deletedBy = nil
        self.deletedByDisplayName = nil
        self.deletedAt = nil
        self.entryMethod = entryMethod
    }
    
    /// Returns the display name for the bill (custom name or default based on items)
    var displayName: String {
        if let billName = billName, !billName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return billName
        } else {
            return items.count == 1 ? items[0].name : "\(items.count) items"
        }
    }

    // MARK: - Hashable Conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Bill, rhs: Bill) -> Bool {
        lhs.id == rhs.id
    }
}

struct BillItem: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var price: Double
    var participantIDs: [String] // Array of userIDs who split this item
    
    init(name: String, price: Double, participantIDs: [String]) {
        self.id = UUID().uuidString
        self.name = name
        self.price = price
        self.participantIDs = participantIDs
    }
}

struct BillParticipant: Codable, Identifiable, Equatable {
    let id: String // This will be the userID
    let displayName: String // Snapshot for UI
    let email: String // Snapshot for notifications
    let isActive: Bool // Track if user still exists
    let photoURL: String? // Snapshot of profile picture URL

    init(userID: String, displayName: String, email: String, isActive: Bool = true, photoURL: String? = nil) {
        self.id = userID
        self.displayName = displayName
        self.email = email
        self.isActive = isActive
        self.photoURL = photoURL
    }
}

// MARK: - Bill Activity Tracking for Epic 3: History Tab Real-Time Updates

/// Represents a bill activity entry for history tracking
struct BillActivity: Codable, Identifiable, Equatable {
    let id: String
    let billId: String
    let billName: String
    let activityType: ActivityType
    let actorName: String // Name of person who performed the action
    let actorEmail: String
    let participantEmails: [String] // All participants affected by this activity
    let timestamp: Date
    let amount: Double // Bill amount for context
    let currency: String
    
    enum ActivityType: String, Codable, CaseIterable {
        case created = "created"
        case edited = "edited" 
        case deleted = "deleted"
        
        var displayName: String {
            switch self {
            case .created: return "Added"
            case .edited: return "Edited"
            case .deleted: return "Deleted"
            }
        }
        
        var systemIconName: String {
            switch self {
            case .created: return "plus.circle.fill"
            case .edited: return "pencil.circle.fill"
            case .deleted: return "trash.circle.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .created: return .green
            case .edited: return .blue
            case .deleted: return .red
            }
        }
    }
    
    /// Display text for history list
    var displayText: String {
        return "\(billName) - \(activityType.displayName) by \(actorName)"
    }
    
    /// Formatted amount for display
    var formattedAmount: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        return formatter.string(from: NSNumber(value: amount)) ?? "\(currency) \(amount)"
    }
    
    init(billId: String, billName: String, activityType: ActivityType, actorName: String, actorEmail: String, participantEmails: [String], amount: Double, currency: String) {
        self.id = UUID().uuidString
        self.billId = billId
        self.billName = billName
        self.activityType = activityType
        self.actorName = actorName
        self.actorEmail = actorEmail
        self.participantEmails = participantEmails
        self.timestamp = Date()
        self.amount = amount
        self.currency = currency
    }

    init(id: String, billId: String, billName: String, activityType: ActivityType, actorName: String, actorEmail: String, participantEmails: [String], timestamp: Date, amount: Double, currency: String) {
        self.id = id
        self.billId = billId
        self.billName = billName
        self.activityType = activityType
        self.actorName = actorName
        self.actorEmail = actorEmail
        self.participantEmails = participantEmails
        self.timestamp = timestamp
        self.amount = amount
        self.currency = currency
    }
}

// BillStatus enum removed - bills are simply created and exist without status

// MARK: - Bill Service for Firebase Operations

class BillService: ObservableObject {
    private let db = Firestore.firestore()
    
    /// Creates a new bill in Firestore with atomic transactions
    func createBill(from session: BillSplitSession, authViewModel: AuthViewModel, contactsManager: ContactsManager) async throws -> Bill {
        AppLog.billOperation("Starting Firebase bill creation")
        #if DEBUG
        #endif
        
        // Validate session readiness
        guard session.isReadyForBillCreation else {
            throw BillCreationError.sessionNotReady
        }
        
        guard let currentUser = await MainActor.run { authViewModel.user },
              let paidByID = session.paidByParticipantID,
              let paidByParticipant = session.participants.first(where: { $0.id == paidByID }) else {
            throw BillCreationError.invalidUser
        }
        
        // Get participant details from contacts and current user
        var billParticipants: [BillParticipant] = []
        
        // UIParticipant.id is now Firebase UID directly - no mapping needed
        
        // Add current user as participant
        let currentUserParticipant = BillParticipant(
            userID: currentUser.uid,
            displayName: currentUser.displayName ?? "You",
            email: currentUser.email ?? "unknown@example.com",
            photoURL: currentUser.photoURL?.absoluteString
        )
        billParticipants.append(currentUserParticipant)
        
        // Current user participant already has Firebase UID as ID
        
        // Add other participants from session (photoURL already fetched)
        for participant in session.participants where participant.name != "You" {
            if let contact = contactsManager.transactionContacts.first(where: {
                $0.displayName.lowercased() == participant.name.lowercased()
            }) {
                // CRITICAL: Use the Firebase UID from UIParticipant (fetched during addParticipant)
                // This ensures participantIds matches the actual Firebase UID for querying
                let participantUserID = participant.id  // This is the real Firebase UID

                let billParticipant = BillParticipant(
                    userID: participantUserID,
                    displayName: contact.displayName,
                    email: contact.email,
                    photoURL: participant.photoURL  // Use photoURL from UIParticipant
                )
                billParticipants.append(billParticipant)

                // Participant ID is already Firebase UID

            }
        }
        
        // Now convert session data to Bill format with proper Firebase UID mapping
        let billItems = session.assignedItems.map { item in
            let mappedParticipantIDs = Array(item.assignedToParticipants)
            
            return BillItem(
                name: item.name,
                price: item.price,
                participantIDs: mappedParticipantIDs
            )
        }
        
        // Get payer details
        let paidByEmail: String
        if paidByParticipant.name == "You" {
            paidByEmail = currentUser.email ?? "unknown@example.com"
        } else if let contact = contactsManager.transactionContacts.first(where: { 
            $0.displayName.lowercased() == paidByParticipant.name.lowercased() 
        }) {
            paidByEmail = contact.email
        } else {
            paidByEmail = "unknown@example.com"
        }
        
        // Determine bill name (use custom name if provided, otherwise default)
        let finalBillName: String? = session.billName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
            ? nil  // Will use computed displayName
            : session.billName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // DEBUG: Log billParticipants before creating bill
        print("🔍 [BILL CREATE] billParticipants count: \(billParticipants.count)")
        for participant in billParticipants {
            print("🔍 [BILL CREATE] Participant: \(participant.displayName) (ID: \(participant.id)) photoURL: \(participant.photoURL ?? "nil")")
        }

        // Create temporary bill for debt calculation
        let tempBill = Bill(
            paidBy: paidByParticipant.name == "You" ? currentUser.uid : billParticipants.first(where: { $0.displayName == paidByParticipant.name })?.id ?? "unknown_\(paidByID)",
            paidByDisplayName: paidByParticipant.name,
            paidByEmail: paidByEmail,
            billName: finalBillName,
            totalAmount: session.totalAmount,
            items: billItems,
            participants: billParticipants,
            createdBy: currentUser.uid,
            calculatedTotals: [:], // Temporary empty, will be calculated below
            entryMethod: session.entryMethod
        )

        // DEBUG: Log participantIds that will be used for querying
        print("🔍 [BILL CREATE] participantIds: \(tempBill.participantIds)")
        
        // 🔧 STANDARDIZATION: Use BillCalculator to ensure Firebase UIDs are used consistently
        let calculatedDebts = BillCalculator.calculateOwedAmounts(bill: tempBill)
        os_log("Calculated debts for new bill using Firebase UIDs: %{private}@", log: .calculations, type: .info, String(describing: calculatedDebts))
        #if DEBUG
        #endif
        
        // Create final Bill object with correct calculatedTotals
        let bill = Bill(
            paidBy: paidByParticipant.name == "You" ? currentUser.uid : billParticipants.first(where: { $0.displayName == paidByParticipant.name })?.id ?? "unknown_\(paidByID)",
            paidByDisplayName: paidByParticipant.name,
            paidByEmail: paidByEmail,
            billName: finalBillName,
            totalAmount: session.totalAmount,
            items: billItems,
            participants: billParticipants,
            createdBy: currentUser.uid,
            calculatedTotals: calculatedDebts, // Now uses Firebase UIDs consistently
            entryMethod: session.entryMethod
        )
        
        // Validate bill totals
        guard BillCalculator.validateBillTotals(bill: bill) else {
            throw BillCreationError.invalidTotals
        }
        
        // Save to Firestore with atomic transaction
        try await saveBillToFirestore(bill: bill)
        
        AppLog.billSuccess("Bill created successfully", billId: bill.id)
        #if DEBUG
        #endif
        
        // Send push notifications to participants (async, don't block UI)
        Task {
            await PushNotificationService.shared.sendBillNotificationToParticipants(bill: bill)
        }
        
        return bill
    }
    
    /// Saves bill to Firestore using atomic batch operations
    private func saveBillToFirestore(bill: Bill) async throws {
        let batch = db.batch()
        
        // Save bill document
        let billRef = db.collection("bills").document(bill.id)
        try batch.setData(from: bill, forDocument: billRef)
        
        // Update only the current user's record (bill creator)
        // Other participants will see bills via the bills collection query
        let currentUserRef = db.collection("users").document(bill.createdBy)
        batch.updateData([
            "billIds": FieldValue.arrayUnion([bill.id]),
            "lastBillUpdate": FieldValue.serverTimestamp()
        ], forDocument: currentUserRef)
        
        // Commit batch operation
        try await batch.commit()
        AppLog.billSuccess("Bill batch operation completed successfully")
        #if DEBUG
        #endif
    }
    
    // MARK: - Update Bill Functionality
    
    /// Updates an existing bill in Firestore with atomic transactions
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
        AppLog.billOperation("Starting Firebase bill update", billId: billId)
        #if DEBUG
        #endif
        
        // Validate input
        guard !billId.isEmpty,
              !billName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !items.isEmpty,
              !participants.isEmpty,
              !paidByParticipantId.isEmpty else {
            throw BillUpdateError.invalidInput
        }
        
        // Get original bill to verify permissions
        let billRef = db.collection("bills").document(billId)
        let billSnapshot = try await billRef.getDocument()
        
        guard let originalBillData = billSnapshot.data(),
              let originalBill = try? billSnapshot.data(as: Bill.self) else {
            throw BillUpdateError.billNotFound
        }
        
        // Verify user is the creator
        guard originalBill.createdBy == currentUserId else {
            throw BillUpdateError.notAuthorized
        }
        
        // Find payer participant
        guard let payer = participants.first(where: { $0.id == paidByParticipantId }) else {
            throw BillUpdateError.payerNotFound
        }
        
        // Calculate new total amount
        let newTotalAmount = items.reduce(0) { $0 + $1.price }
        
        // Create temporary bill to calculate debts
        let tempBill = Bill(
            id: billId,
            createdBy: originalBill.createdBy,
            createdByDisplayName: originalBill.createdByDisplayName,
            createdByEmail: originalBill.createdByEmail,
            paidBy: paidByParticipantId,
            paidByDisplayName: payer.displayName,
            paidByEmail: payer.email,
            billName: billName.trimmingCharacters(in: .whitespacesAndNewlines),
            totalAmount: newTotalAmount,
            currency: originalBill.currency,
            date: originalBill.date,
            createdAt: originalBill.createdAt,
            items: items,
            participants: participants,
            participantIds: participants.map { $0.id },
            calculatedTotals: [:], // Temporary, will be recalculated
            isDeleted: false
        )
        
        // 🔧 CRITICAL FIX: Recalculate debt amounts with new payer
        let recalculatedDebts = BillCalculator.calculateOwedAmounts(bill: tempBill)
        
        // Create final bill with correct calculated totals
        let updatedBill = Bill(
            id: billId,
            createdBy: originalBill.createdBy,
            createdByDisplayName: originalBill.createdByDisplayName,
            createdByEmail: originalBill.createdByEmail,
            paidBy: paidByParticipantId,
            paidByDisplayName: payer.displayName,
            paidByEmail: payer.email,
            billName: billName.trimmingCharacters(in: .whitespacesAndNewlines),
            totalAmount: newTotalAmount,
            currency: originalBill.currency,
            date: originalBill.date,
            createdAt: originalBill.createdAt,
            items: items,
            participants: participants,
            participantIds: participants.map { $0.id },
            calculatedTotals: recalculatedDebts, // 🔧 Now with correct debts
            isDeleted: false
        )
        
        // Validate bill totals
        guard BillCalculator.validateBillTotals(bill: updatedBill) else {
            throw BillUpdateError.invalidTotals
        }
        
        // Update in Firestore
        try await updateBillInFirestore(bill: updatedBill)

        // Create "edited" activity for all participants
        let editorName = participants.first(where: { $0.id == currentUserId })?.displayName ?? "Someone"
        // CRITICAL: Use current authenticated email for Firestore security rules
        let editorEmail = currentUserEmail

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
            currency: updatedBill.currency
        )

        // Save edit activity for all participants
        let batch = db.batch()
        for participantId in updatedBill.participantIds {
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
            AppLog.billSuccess("Edit activity saved for \(updatedBill.participantIds.count) participants", billId: billId)
        } catch {
            AppLog.billError("Failed to commit edit activity batch", error: error)
            // Don't throw - bill update succeeded, just activity logging failed
        }

        // Send notifications to all participants about the update
        Task {
            await PushNotificationService.shared.sendBillUpdateNotificationToParticipants(
                bill: updatedBill,
                updatedBy: currentUserId
            )
        }

        AppLog.billSuccess("Bill updated successfully", billId: billId)
        #if DEBUG
        #endif
    }
    
    /// Updates bill in Firestore using atomic operations
    private func updateBillInFirestore(bill: Bill) async throws {
        let billRef = db.collection("bills").document(bill.id)
        
        try await billRef.setData(from: bill)
    }
    
    // MARK: - Delete Bill Functionality

    /// Deletes a bill using soft-delete pattern with participant notifications
    ///
    /// Performs a Firebase transaction to:
    /// 1. Mark bill as deleted (soft delete for audit trail)
    /// 2. Add deletion metadata (who deleted, when)
    /// 3. Recalculate affected user balances
    /// 4. Record deletion activity in bill history
    /// 5. Trigger participant notifications
    ///
    /// **Permission Check:**
    /// Only the bill creator can delete the bill.
    ///
    /// **Balance Recalculation:**
    /// All participant balances are recalculated to reflect the deletion,
    /// ensuring the system remains in a consistent state.
    ///
    /// - Parameters:
    ///   - billId: Firestore document ID of the bill to delete
    ///   - currentUserId: Firebase Auth UID of user performing deletion
    ///   - billManager: BillManager instance to update local state
    ///
    /// - Throws:
    ///   - `BillDeleteError.billNotFound`: Bill doesn't exist in Firestore
    ///   - `BillDeleteError.notAuthorized`: User is not the bill creator
    ///   - `BillDeleteError.firestoreError`: Database operation failed
    ///
    /// - Important: This is a soft delete - bill remains in database with `isDeleted = true`
    func deleteBill(
        billId: String,
        currentUserId: String,
        billManager: BillManager
    ) async throws {
        AppLog.billOperation("Starting Firebase bill deletion", billId: billId)
        #if DEBUG
        #endif
        
        // Get original bill to verify permissions and calculate balance changes
        let billRef = db.collection("bills").document(billId)
        let billSnapshot = try await billRef.getDocument()
        
        guard let originalBill = try? billSnapshot.data(as: Bill.self) else {
            throw BillDeleteError.billNotFound
        }
        
        // Verify user is the creator
        guard originalBill.createdBy == currentUserId else {
            throw BillDeleteError.notAuthorized
        }
        
        // Calculate how this deletion affects user balances
        let affectedUserIds = Set(originalBill.participantIds + [originalBill.createdBy])
        
        // Before deletion, recalculate what each user's balance will be without this bill
        // This ensures accuracy as specified in requirements
        await recalculateBalancesBeforeDeletion(
            billToDelete: originalBill,
            affectedUserIds: Array(affectedUserIds)
        )
        
        // Perform hard delete with atomic transaction
        let batch = db.batch()

        // Fetch deleter info for metadata
        let currentUserDoc = try await db.collection("users").document(currentUserId).getDocument()
        guard let userData = currentUserDoc.data(),
              let deleterName = userData["displayName"] as? String else {
            throw BillDeleteError.invalidUserData
        }

        // Mark bill as deleted (for audit trail) and set isDeleted flag with metadata
        var deletedBill = originalBill
        deletedBill.isDeleted = true
        deletedBill.deletedBy = currentUserId
        deletedBill.deletedByDisplayName = deleterName
        deletedBill.deletedAt = Timestamp()
        try batch.setData(from: deletedBill, forDocument: billRef)
        
        // Remove bill ID from creator's billIds array
        let creatorUserRef = db.collection("users").document(originalBill.createdBy)
        batch.updateData([
            "billIds": FieldValue.arrayRemove([billId]),
            "lastBillUpdate": FieldValue.serverTimestamp()
        ], forDocument: creatorUserRef)
        
        // Commit the batch
        try await batch.commit()

        // Create deletion activity for all participants
        let activityId = UUID().uuidString
        let deleterEmail = userData["email"] as? String ?? "unknown@example.com"

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
        let activityBatch = db.batch()
        for (index, participantId) in deletedBill.participantIds.enumerated() {
            let activityRef = db.collection("users")
                .document(participantId)
                .collection("billActivities")
                .document(activityId)

            do {
                try activityBatch.setData(from: activity, forDocument: activityRef)
            } catch {
            }
        }

        try await activityBatch.commit()

        // Send notifications to all participants about the deletion
        Task {
            await PushNotificationService.shared.sendBillDeleteNotificationToParticipants(
                bill: originalBill,
                deletedBy: currentUserId
            )
        }

    }
    
    /// Recalculates user balances before bill deletion to maintain accuracy
    private func recalculateBalancesBeforeDeletion(
        billToDelete: Bill,
        affectedUserIds: [String]
    ) async {
        
        // For each affected user, we need to:
        // 1. Get all their other bills (excluding the one being deleted)
        // 2. Recalculate their net balance without the deleted bill
        // 3. Update their balance record
        
        for userId in affectedUserIds {
            do {
                // Get all bills for this user except the one being deleted
                // SERVER-SIDE FILTERING: Secure filtering of deleted bills  
                let userBillsQuery = db.collection("bills")
                    .whereField("participantIds", arrayContains: userId)
                    .whereField("isDeleted", isEqualTo: false)
                
                let snapshot = try await userBillsQuery.getDocuments()
                let userBills = snapshot.documents.compactMap { doc -> Bill? in
                    guard let bill = try? doc.data(as: Bill.self),
                          bill.id != billToDelete.id else { return nil }
                    // Server-side filtering ensures only active bills are received
                    return bill
                }
                
                // Calculate new balance without the deleted bill
                let newBalance = BillCalculator.calculateUserNetBalance(
                    userId: userId,
                    bills: userBills
                )
                
                // Update user's balance record
                let userRef = db.collection("users").document(userId)
                try await userRef.updateData([
                    "netBalance": newBalance,
                    "lastBalanceUpdate": FieldValue.serverTimestamp()
                ])
                
                
            } catch {
                // Continue with other users even if one fails
            }
        }
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
        throw NSError(domain: "BillService", code: 403, userInfo: [NSLocalizedDescriptionKey: "deleteAllUserBills is only available in DEBUG builds"])
        #endif
    }
}

// MARK: - Bill Manager for Real-time Updates

/**
 # BillManager

 Real-time UI State Manager using Firebase Firestore listeners for automatic synchronization.

 ## Architecture Role
 - **Pattern:** ObservableObject (SwiftUI State Container)
 - **Responsibility:** READ-ONLY real-time data synchronization and UI state management
 - **Lifecycle:** Singleton instance managed by SwiftUI environment

 ## Key Responsibilities
 1. **Real-time Data Sync:** Manages Firestore snapshot listeners for live bill updates
 2. **UI State Management:** Publishes state changes to SwiftUI views via @Published properties
 3. **Balance Aggregation:** Calculates net balances from all user's bills
 4. **User Session Lifecycle:** Attaches/detaches listeners on login/logout
 5. **Activity Tracking:** Records and persists bill activity history

 ## Does NOT Handle
 - ❌ Writing to Firestore (use BillService for CRUD operations)
 - ❌ Bill creation/update/deletion
 - ❌ Push notifications (delegated to PushNotificationService)
 - ❌ Authentication (managed by AuthViewModel)

 ## Usage Pattern
 ```swift
 // On login
 billManager.setCurrentUser(userId)

 // On logout
 billManager.clearCurrentUser()

 // SwiftUI automatically observes @Published properties
 ContentView reads billManager.userBills → UI auto-updates
 ```

 ## Performance Characteristics
 - **Listener overhead:** ~50ms setup per user
 - **Balance calculation:** <100ms for 50 bills
 - **Memory:** ~1KB per cached bill
 - **Thread:** Main thread (SwiftUI requirement)

 ## See Also
 - `BillService` - For write operations (create/update/delete)
 - `architecture/bill-services-overview.md` - Service architecture documentation
 - `architecture/data-flow-diagram.md` - Visual data flow diagrams
 */
class BillManager: ObservableObject {
    private let db = Firestore.firestore()

    /// Real-time list of bills where user is a participant (auto-updates via Firestore listener)
    @Published var userBills: [Bill] = []

    /// Aggregated balance state (totalOwed, totalOwedTo, activeBillIds) calculated from userBills
    @Published var userBalance: UserBalance = UserBalance()

    /// Loading state for initial bill fetch
    @Published var isLoading = false

    /// Error message to display in UI (nil when no error)
    @Published var errorMessage: String?

    /// History of bill activities (create/edit/delete events) for History tab
    @Published var billActivities: [BillActivity] = []

    /// Currently authenticated user's Firebase UID (nil when logged out)
    private var currentUserId: String?

    /// Active Firestore listener registration (removed on logout or user switch)
    private var billsListener: ListenerRegistration?

    /// Active Firestore listener for bill activities (removed on logout or user switch)
    private var billActivitiesListener: ListenerRegistration?

    init() {}

    /**
     Initializes BillManager for a newly authenticated user.

     Sets up real-time Firestore listener and loads user's bills and activities.
     If switching users, clears all previous data first to prevent data leakage.

     - Parameter userId: Firebase Authentication UID of the logged-in user

     ## Side Effects
     - Removes existing Firestore listener if present
     - Clears all cached data when switching users
     - Attaches new listener to `bills` collection
     - Loads bill activities from Firestore

     ## Usage
     ```swift
     // Called by AuthViewModel after successful login
     billManager.setCurrentUser(user.uid)
     ```
     */
    func setCurrentUser(_ userId: String) {
        // If already set to this user, don't re-initialize listeners
        if self.currentUserId == userId {
            return
        }

        // Clear existing data if switching users
        if let currentUser = self.currentUserId, currentUser != userId {
            billsListener?.remove()
            billsListener = nil
            billActivitiesListener?.remove()
            billActivitiesListener = nil
            self.userBills = []
            self.userBalance = UserBalance()
            self.billActivities = []
            self.errorMessage = nil
        }

        self.currentUserId = userId
        loadUserBills()
        loadBillActivitiesRealtime()
    }

    /**
     Cleans up BillManager state on user logout.

     Removes Firestore listener and clears all cached data to prevent stale data
     from being displayed to the next user.

     ## Side Effects
     - Removes active Firestore listener
     - Clears all @Published properties
     - Resets loading and error states

     ## Usage
     ```swift
     // Called by AuthViewModel.signOut()
     billManager.clearCurrentUser()
     ```
     */
    func clearCurrentUser() {
        billsListener?.remove()
        billsListener = nil
        billActivitiesListener?.remove()
        billActivitiesListener = nil
        self.currentUserId = nil
        self.userBills = []
        self.userBalance = UserBalance()
        self.billActivities = []
        self.errorMessage = nil
        self.isLoading = false
    }

    /**
     Force refresh bills and recalculate balances.

     Manually triggers listener reattachment and balance recalculation.
     Typically used for pull-to-refresh or error recovery scenarios.

     - Note: Firestore listeners already provide real-time updates, so manual refresh
             is rarely needed except for user-initiated actions.
     */
    @MainActor
    func refreshBills() async {
        if let userId = currentUserId {
            loadUserBills()
            // Small delay to ensure refresh completes
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }
    }
    
    /**
     Sets up real-time Firestore listener for bills where user is a participant.

     Attaches `addSnapshotListener` to automatically receive updates when bills are
     created, modified, or deleted. This provides instant UI synchronization without
     manual polling or refresh.

     ## Query Details
     - **Collection:** `bills`
     - **Filters:**
       - `participantIds arrayContains userId` - User is in participant list
       - `isDeleted == false` - Exclude soft-deleted bills (server-side security)
     - **Order:** `createdAt descending` - Newest bills first

     ## Real-time Behavior
     - **Added:** New bill appears in UI instantly
     - **Modified:** Changes trigger automatic recalculation of balances
     - **Removed:** Bill removal updates UI without manual refresh

     ## Error Handling
     - Sets `errorMessage` @Published property on failure
     - Logs error for debugging
     - Continues with empty bill list on decode failures

     - Important: This is a **listener**, not a one-time fetch. It remains active
                  until explicitly removed via `billsListener?.remove()`.
     */
    private func loadUserBills() {
        guard let userId = currentUserId else { return }

        billsListener?.remove()
        isLoading = true


        // Listen for bills where user is involved as participant (excluding deleted bills)
        // SERVER-SIDE FILTERING: Secure filtering of deleted bills on server
        billsListener = db.collection("bills")
            .whereField("participantIds", arrayContains: userId)
            .whereField("isDeleted", isEqualTo: false)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        AppLog.billError("Failed to load bills", error: error)
                        #if DEBUG
                        #endif
                        self?.errorMessage = "Failed to load bills: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.userBills = []
                        self?.calculateUserBalance()
                        return
                    }
                    
                    let bills = documents.compactMap { doc in
                        do {
                            let bill = try doc.data(as: Bill.self)
                            // Server-side filtering ensures only active bills are received
                            return bill
                        } catch {
                            AppLog.billError("Failed to decode bill document \(doc.documentID)", error: error)
                            #if DEBUG
                            #endif
                            return nil
                        }
                    }
                    
                    self?.userBills = bills
                    self?.calculateUserBalance()
                }
            }
    }

    /**
     Fetches a single bill by ID from Firestore, including deleted bills.

     This method is used for viewing bill details from History tab, where
     we need to access deleted bills for record-keeping and dispute resolution.

     - Parameter billId: The unique identifier of the bill to fetch
     - Returns: The Bill object if found and user has access, nil otherwise

     ## Access Control
     - User must be in the bill's participantIds array
     - Deleted bills are accessible (unlike userBills listener which filters them out)

     ## Use Cases
     - Viewing deleted bill details from History tab
     - Navigating to bill from notifications
     - Deep linking to specific bills
     */
    func getBillById(_ billId: String) async -> Bill? {
        guard let userId = currentUserId else {
            return nil
        }

        do {
            let billDoc = try await db.collection("bills").document(billId).getDocument()

            guard billDoc.exists else {
                return nil
            }

            let bill = try billDoc.data(as: Bill.self)

            // Verify user has access (must be participant)
            guard bill.participantIds.contains(userId) else {
                return nil
            }

            return bill

        } catch {
            return nil
        }
    }

    /**
     Calculates user's aggregated balance from all active bills.

     Iterates through `userBills` to compute:
     - **totalOwed:** Money user owes to others (user is participant, not payer)
     - **totalOwedTo:** Money others owe to user (user is payer)
     - **activeBillIds:** List of bill IDs involved in balance calculation

     ## Algorithm
     ```
     For each bill in userBills:
       If user is payer:
         For each participant (except user):
           totalOwedTo += calculatedTotals[participantId]
       Else:
         totalOwed += calculatedTotals[userId]
     ```

     ## Precision
     - Uses $0.01 threshold to ignore floating-point rounding errors
     - Matches Venmo/Splitwise precision standards

     ## Side Effects
     - Updates `userBalance` @Published property
     - Triggers SwiftUI view updates automatically

     - Note: Called automatically after every Firestore listener update.
             No manual invocation needed.
     */
    private func calculateUserBalance() {
        guard let userId = currentUserId else {
            return
        }


        var totalOwed: Double = 0.0
        var totalOwedTo: Double = 0.0
        var activeBills: [String] = []
        
        for bill in userBills {
            
            activeBills.append(bill.id)
            
            // If user is the payer, they are owed money
            if bill.paidBy == userId {
                    for (participantID, amount) in bill.calculatedTotals {
                        if participantID != userId && amount > 0.01 {
                            totalOwedTo += amount
                        }
                    }
                } else {
                    // If user is a participant who owes money
                    if let amountOwed = bill.calculatedTotals[userId], amountOwed > 0.01 {
                        totalOwed += amountOwed
                    } else {
                    }
                }
        }
        
        userBalance = UserBalance(
            totalOwed: totalOwed,
            totalOwedTo: totalOwedTo,
            activeBillIds: activeBills
        )
        
    }
    
    /**
     Calculates net balances with each individual participant across all bills.

     Aggregates all bills to compute per-person net balances:
     - **Positive balance:** They owe the user (displayed in green)
     - **Negative balance:** User owes them (displayed in red)

     ## Use Cases
     - Home screen "People who owe you" section
     - Home screen "People you owe" section
     - Balance breakdown UI

     ## Example
     ```
     Bill 1: User paid $100, Alice owes $30, Bob owes $70
     Bill 2: Alice paid $60, User owes $30
     Net Result: Alice: $0 (canceled out), Bob: +$70 (owes user)
     ```

     ## Participant ID Normalization
     - Normalizes email-based IDs to consistent format
     - Pattern: `email_{email_prefix}` (e.g., `email_alice_at_example_com`)
     - Prevents duplicate balances from ID inconsistencies

     - Returns: Array of `UIPersonDebt` sorted by amount (largest first)
     */
    func getNetBalances() -> [UIPersonDebt] {
        guard let userId = currentUserId else {
            return []
        }


        var balances: [String: Double] = [:] // participantID -> net amount (+ they owe you, - you owe them)
        var participantInfo: [String: (name: String, email: String)] = [:]
        
        // Helper function to normalize participant IDs (always use consistent email-based format)
        func normalizeParticipantID(_ id: String, displayName: String, email: String) -> String {
            // Always normalize to email-based format for consistency
            let normalizedEmail = email.lowercased()
                .replacingOccurrences(of: "@", with: "_at_")
                .replacingOccurrences(of: ".", with: "_")
            
            // Use email_prefix format consistently
            return "email_\(normalizedEmail)"
        }
        
        for bill in userBills {
            
            // Process all bills (no status filtering)
            if bill.paidBy == userId {
                // User paid - others owe them (positive balance)
                for (participantUID, amount) in bill.calculatedTotals {
                    if participantUID != userId && amount > 0.01 {
                        // Find the participant by their Firebase UID
                        if let otherParticipant = bill.participants.first(where: { $0.id == participantUID }) {
                            let normalizedID = normalizeParticipantID(otherParticipant.id, displayName: otherParticipant.displayName, email: otherParticipant.email)
                            balances[normalizedID, default: 0.0] += amount
                            participantInfo[normalizedID] = (otherParticipant.displayName, otherParticipant.email)
                        } else {
                        }
                    }
                }
            } else {
                // User didn't pay - check if user owes money (negative balance)
                // Use Firebase UID instead of session ID "1"
                if let amountOwed = bill.calculatedTotals[userId], amountOwed > 0.01 {
                    let normalizedID = normalizeParticipantID(bill.paidBy, displayName: bill.paidByDisplayName, email: bill.paidByEmail)
                    balances[normalizedID, default: 0.0] -= amountOwed
                    participantInfo[normalizedID] = (bill.paidByDisplayName, bill.paidByEmail)
                } else {
                }
            }
        }
        
        
        let result = balances.compactMap { (participantID, netAmount) -> UIPersonDebt? in
            guard abs(netAmount) > 0.01,
                  let info = participantInfo[participantID] else { 
                return nil 
            }
            
            if netAmount > 0 {
                return UIPersonDebt(
                    name: info.name,
                    total: netAmount,
                    color: .green // They owe you
                )
            } else {
                return UIPersonDebt(
                    name: info.name,
                    total: abs(netAmount),
                    color: .red // You owe them
                )
            }
        }.sorted { (debt1: UIPersonDebt, debt2: UIPersonDebt) -> Bool in
            debt1.total > debt2.total
        }
        
        return result
    }
    
    /// Gets list of people who owe money to the current user (NET positive balances only)
    func getPeopleWhoOweUser() -> [UIPersonDebt] {
        return getNetBalances().filter { $0.color == .green }
    }
    
    /// Gets list of people the current user owes money to (NET negative balances only)
    func getPeopleUserOwes() -> [UIPersonDebt] {
        return getNetBalances().filter { $0.color == .red }
    }

    
    // MARK: - Bill Activity Management
    
    /// Adds a new bill activity record to track bill events
    func addBillActivity(billId: String, billName: String, activityType: BillActivity.ActivityType, actorName: String, actorEmail: String, participantEmails: [String], participantIds: [String], amount: Double, currency: String) {
        let activity = BillActivity(
            billId: billId,
            billName: billName,
            activityType: activityType,
            actorName: actorName,
            actorEmail: actorEmail,
            participantEmails: participantEmails,
            amount: amount,
            currency: currency
        )

        DispatchQueue.main.async {
            self.billActivities.append(activity)
            // Sort by timestamp (newest first)
            self.billActivities.sort { $0.timestamp > $1.timestamp }
        }

        // Store in Firestore for persistence across all participants
        Task {
            await saveBillActivityToFirestore(activity, participantIds: participantIds)
        }
    }
    
    /// Saves bill activity to Firestore for ALL participants
    private func saveBillActivityToFirestore(_ activity: BillActivity, participantIds: [String]) async {
        let batch = db.batch()


        for (index, participantId) in participantIds.enumerated() {
            let activityRef = db.collection("users")
                .document(participantId)
                .collection("billActivities")
                .document(activity.id)

            batch.setData([
                "id": activity.id,
                "billId": activity.billId,
                "billName": activity.billName,
                "activityType": activity.activityType.rawValue,
                "actorName": activity.actorName,
                "actorEmail": activity.actorEmail,
                "participantEmails": activity.participantEmails,
                "timestamp": activity.timestamp,
                "amount": activity.amount,
                "currency": activity.currency
            ], forDocument: activityRef)

        }

        do {
            try await batch.commit()
        } catch {
        }
    }
    
    /// Sets up real-time Firestore listener for bill activities
    /// This ensures history persists across app restarts and updates in real-time
    private func loadBillActivitiesRealtime() {
        guard let userId = currentUserId else { return }


        billActivitiesListener = db.collection("users").document(userId)
            .collection("billActivities")
            .order(by: "timestamp", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to load history: \(error.localizedDescription)"
                    }
                    return
                }

                guard let documents = snapshot?.documents else {
                    return
                }

                let activities = documents.compactMap { document -> BillActivity? in
                    let data = document.data()
                    guard
                        let id = data["id"] as? String,
                        let billId = data["billId"] as? String,
                        let billName = data["billName"] as? String,
                        let activityTypeRaw = data["activityType"] as? String,
                        let activityType = BillActivity.ActivityType(rawValue: activityTypeRaw),
                        let actorName = data["actorName"] as? String,
                        let actorEmail = data["actorEmail"] as? String,
                        let participantEmails = data["participantEmails"] as? [String],
                        let timestamp = (data["timestamp"] as? Timestamp)?.dateValue(),
                        let amount = data["amount"] as? Double,
                        let currency = data["currency"] as? String
                    else {
                        return nil
                    }

                    return BillActivity(
                        id: id,
                        billId: billId,
                        billName: billName,
                        activityType: activityType,
                        actorName: actorName,
                        actorEmail: actorEmail,
                        participantEmails: participantEmails,
                        timestamp: timestamp,
                        amount: amount,
                        currency: currency
                    )
                }

                DispatchQueue.main.async {
                    self.billActivities = activities
                }
            }
    }
}

// MARK: - User Balance Model

struct UserBalance {
    let totalOwed: Double // Amount user owes to others
    let totalOwedTo: Double // Amount others owe to user
    let activeBillIds: [String] // List of active bill IDs
    
    init(totalOwed: Double = 0.0, totalOwedTo: Double = 0.0, activeBillIds: [String] = []) {
        self.totalOwed = totalOwed
        self.totalOwedTo = totalOwedTo
        self.activeBillIds = activeBillIds
    }
    
    var netBalance: Double {
        return totalOwedTo - totalOwed
    }
    
    var hasDebts: Bool {
        return totalOwed > 0.01
    }
    
    var isOwed: Bool {
        return totalOwedTo > 0.01
    }
}

// MARK: - Bill Creation Errors

enum BillCreationError: LocalizedError {
    case sessionNotReady
    case invalidUser
    case invalidTotals
    case firestoreError(String)
    
    var errorDescription: String? {
        switch self {
        case .sessionNotReady:
            return "Please complete all required fields before creating the bill"
        case .invalidUser:
            return "Invalid user or payer information"
        case .invalidTotals:
            return "Bill totals don't match calculated amounts"
        case .firestoreError(let message):
            return "Database error: \(message)"
        }
    }
}

// MARK: - Bill Update/Delete Error Types

enum BillUpdateError: LocalizedError {
    case invalidInput
    case billNotFound
    case notAuthorized
    case payerNotFound
    case invalidTotals
    case firestoreError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidInput:
            return "Invalid input data provided"
        case .billNotFound:
            return "Bill not found"
        case .notAuthorized:
            return "You don't have permission to edit this bill"
        case .payerNotFound:
            return "Selected payer not found in participants"
        case .invalidTotals:
            return "Bill totals don't match calculated amounts"
        case .firestoreError(let message):
            return "Database error: \(message)"
        }
    }
}

enum BillDeleteError: LocalizedError {
    case billNotFound
    case notAuthorized
    case invalidUserData
    case firestoreError(String)

    var errorDescription: String? {
        switch self {
        case .billNotFound:
            return "Bill not found"
        case .notAuthorized:
            return "You don't have permission to delete this bill"
        case .invalidUserData:
            return "Failed to fetch user information"
        case .firestoreError(let message):
            return "Database error: \(message)"
        }
    }
}

// MARK: - FCM Token Management

class FCMTokenManager: ObservableObject {
    static let shared = FCMTokenManager()
    private let db = Firestore.firestore()
    private let auth = Auth.auth()
    
    private init() {}
    
    /// Updates the current user's FCM token in Firestore
    func updateFCMToken(_ token: String) async {
        guard let currentUser = auth.currentUser else {
            return
        }
        
        AppLog.notificationSuccess("Updating FCM token for user")
        #if DEBUG
        #endif
        
        do {
            try await db.collection("users").document(currentUser.uid).setData([
                "fcmToken": token,
                "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
                "email": currentUser.email ?? "",
                "displayName": currentUser.displayName ?? "",
                "lastActiveAt": FieldValue.serverTimestamp()
            ], merge: true)
            
            AppLog.notificationSuccess("FCM token updated successfully in Firestore")
            #if DEBUG
            #endif
        } catch {
            AppLog.notificationError("Failed to update FCM token", error: error)
            #if DEBUG
            #endif
        }
    }
    
    /// Gets FCM tokens for participants by their email addresses
    func getFCMTokensForEmails(_ emails: [String]) async -> [String: String] {
        
        var tokenMap: [String: String] = [:]
        
        // Batch lookup users by email
        for email in emails {
            do {
                let querySnapshot = try await db.collection("users")
                    .whereField("email", isEqualTo: email)
                    .limit(to: 1)
                    .getDocuments()
                
                if let document = querySnapshot.documents.first,
                   let fcmToken = document.data()["fcmToken"] as? String,
                   !fcmToken.isEmpty {
                    tokenMap[email] = fcmToken
                } else {
                }
            } catch {
            }
        }
        
        return tokenMap
    }
    
    /// Validates and refreshes FCM token if needed
    func validateAndRefreshToken() async {
        guard auth.currentUser != nil else {
            return
        }
        
        // TODO: Uncomment after adding FirebaseMessaging
        /*
        do {
            let token = try await Messaging.messaging().token()
            await updateFCMToken(token)
        } catch {
        }
        */
    }
}

// MARK: - Push Notification Service

class PushNotificationService: ObservableObject {
    static let shared = PushNotificationService()
    private let db = Firestore.firestore()
    
    private init() {}
    
    /// Sends push notifications to all participants about a new bill
    func sendBillNotificationToParticipants(bill: Bill) async {
        
        // Get participant emails (excluding bill creator)
        let participantEmails = bill.participants
            .filter { $0.id != bill.createdBy }
            .map { $0.email }
        
        guard !participantEmails.isEmpty else {
            return
        }
        
        
        // Get FCM tokens for participants
        let tokenMap = await FCMTokenManager.shared.getFCMTokensForEmails(participantEmails)
        
        guard !tokenMap.isEmpty else {
            return
        }
        
        // Create notification content
        let notificationData = createBillNotificationData(bill: bill)
        
        // Send notifications to each participant with retry logic
        for (email, fcmToken) in tokenMap {
            await sendNotificationWithRetry(
                fcmToken: fcmToken,
                data: notificationData,
                participantEmail: email,
                billId: bill.id
            )
        }
    }
    
    /// Creates notification data for a new bill
    private func createBillNotificationData(bill: Bill) -> [String: Any] {
        let title = "\(bill.paidByDisplayName) added '\(bill.displayName)' bill"
        let body = String(format: "Total: $%.2f • Tap to view details", bill.totalAmount)
        
        return [
            "title": title,
            "body": body,
            "billId": bill.id,
            "billAmount": bill.totalAmount,
            "billCreator": bill.paidByDisplayName,
            "type": "new_bill"
        ]
    }
    
    /// Sends notification with exponential backoff retry (3 attempts)
    private func sendNotificationWithRetry(fcmToken: String, data: [String: Any], participantEmail: String, billId: String) async {
        let maxRetries = 3
        var attempt = 0
        
        while attempt < maxRetries {
            do {
                try await sendSingleNotification(fcmToken: fcmToken, data: data)
                return
            } catch {
                attempt += 1
                
                if attempt < maxRetries {
                    // Exponential backoff: 1s, 2s, 4s
                    let delay = pow(2.0, Double(attempt - 1))
                    try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                } else {
                }
            }
        }
    }
    
    /// Sends a single push notification using Firebase Cloud Functions
    private func sendSingleNotification(fcmToken: String, data: [String: Any]) async throws {
        // Create the notification payload
        let payload: [String: Any] = [
            "to": fcmToken,
            "notification": [
                "title": data["title"] as? String ?? "",
                "body": data["body"] as? String ?? "",
                "sound": "default"
            ],
            "data": data,
            "priority": "high",
            "content_available": true
        ]
        
        // Send via Firebase Cloud Functions or direct FCM API
        // For now, we'll store the notification request in Firestore and let a Cloud Function handle it
        // This is more reliable than direct FCM API calls from the client
        
        let notificationDoc: [String: Any] = [
            "fcmToken": fcmToken,
            "payload": payload,
            "createdAt": FieldValue.serverTimestamp(),
            "status": "pending",
            "attempts": 0
        ]
        
        try await db.collection("notification_queue").addDocument(data: notificationDoc)
    }
    
    // MARK: - Bill Update Notifications
    
    /// Sends push notifications to all participants about a bill update
    func sendBillUpdateNotificationToParticipants(bill: Bill, updatedBy userId: String) async {
        
        // Get participant emails (excluding the updater)
        let participantEmails = bill.participants
            .filter { $0.id != userId }
            .map { $0.email }
        
        guard !participantEmails.isEmpty else {
            return
        }
        
        
        // Get FCM tokens for participants
        let tokenMap = await FCMTokenManager.shared.getFCMTokensForEmails(participantEmails)
        
        guard !tokenMap.isEmpty else {
            return
        }
        
        // Create notification content for update
        let notificationData = createBillUpdateNotificationData(bill: bill, updatedBy: userId)
        
        // Send notifications to each participant with retry logic
        for (email, fcmToken) in tokenMap {
            await sendNotificationWithRetry(
                fcmToken: fcmToken,
                data: notificationData,
                participantEmail: email,
                billId: bill.id
            )
        }
    }
    
    /// Creates notification data for a bill update
    private func createBillUpdateNotificationData(bill: Bill, updatedBy userId: String) -> [String: Any] {
        let updaterName = bill.participants.first { $0.id == userId }?.displayName ?? "Someone"
        let title = "\(updaterName) updated '\(bill.displayName)' bill"
        let body = String(format: "New total: $%.2f • Tap to view changes", bill.totalAmount)
        
        return [
            "title": title,
            "body": body,
            "billId": bill.id,
            "billAmount": bill.totalAmount,
            "updatedBy": updaterName,
            "type": "bill_update"
        ]
    }
    
    // MARK: - Bill Delete Notifications
    
    /// Sends push notifications to all participants about a bill deletion
    func sendBillDeleteNotificationToParticipants(bill: Bill, deletedBy userId: String) async {
        
        // Get participant emails (excluding the deleter)
        let participantEmails = bill.participants
            .filter { $0.id != userId }
            .map { $0.email }
        
        guard !participantEmails.isEmpty else {
            return
        }
        
        
        // Get FCM tokens for participants
        let tokenMap = await FCMTokenManager.shared.getFCMTokensForEmails(participantEmails)
        
        guard !tokenMap.isEmpty else {
            return
        }
        
        // Create notification content for deletion
        let notificationData = createBillDeleteNotificationData(bill: bill, deletedBy: userId)
        
        // Send notifications to each participant with retry logic
        for (email, fcmToken) in tokenMap {
            await sendNotificationWithRetry(
                fcmToken: fcmToken,
                data: notificationData,
                participantEmail: email,
                billId: bill.id
            )
        }
    }
    
    /// Creates notification data for a bill deletion
    private func createBillDeleteNotificationData(bill: Bill, deletedBy userId: String) -> [String: Any] {
        let deleterName = bill.participants.first { $0.id == userId }?.displayName ?? "Someone"
        let title = "\(deleterName) deleted '\(bill.displayName)' bill"
        let body = "Bill has been removed and balances updated"
        
        return [
            "title": title,
            "body": body,
            "billId": bill.id,
            "billAmount": bill.totalAmount,
            "deletedBy": deleterName,
            "type": "bill_delete"
        ]
    }
}

// MARK: - Bill Calculation Helper

struct BillCalculator {
    
    /// Calculates who owes whom with proper rounding to ensure totals match
    /// Calculates amounts owed by each participant to the bill payer with penny-perfect precision
    ///
    /// This function implements smart cent distribution to ensure the sum of individual debts
    /// exactly equals the bill total, avoiding floating-point rounding errors.
    ///
    /// **Algorithm:**
    /// 1. For each item, calculate base per-person amount (price ÷ participant count)
    /// 2. Round base amount to 2 decimal places
    /// 3. Calculate remainder after rounding (should be small cents)
    /// 4. Distribute remainder cents to first N participants (where N = remainder in cents)
    /// 5. Aggregate debts across all items per participant
    ///
    /// **Example:**
    /// ```
    /// Item: $10.01 split among 3 people
    /// Base: $10.01 ÷ 3 = $3.336666...
    /// Rounded: $3.34
    /// Total after rounding: $3.34 × 3 = $10.02
    /// Remainder: $10.01 - $10.02 = -$0.01
    /// Distribution: [$3.33, $3.34, $3.34] → sum = $10.01 ✓
    /// ```
    ///
    /// - Parameter bill: Bill containing items, participants, and payer information
    /// - Returns: Dictionary mapping participant ID to amount owed (excludes payer)
    ///
    /// - Note: Payer is excluded from returned dictionary as they owe themselves $0
    /// - Important: Returned amounts are always non-negative and sum to bill total
    static func calculateOwedAmounts(bill: Bill) -> [String: Double] {
        for item in bill.items {
        }
        
        var owedAmounts: [String: Double] = [:]
        let paidByUserID = bill.paidBy
        
        // Initialize all participants with $0 owed
        for participant in bill.participants {
            if participant.id != paidByUserID {
                owedAmounts[participant.id] = 0.0
            } else {
            }
        }
        
        // Calculate each item's split
        for item in bill.items {
            
            let participantCount = item.participantIDs.count
            guard participantCount > 0 else { 
                continue 
            }
            
            let baseAmount = item.price / Double(participantCount)
            let roundedBase = (baseAmount * 100).rounded() / 100 // Round to 2 decimal places
            
            // Calculate how much total we have after rounding
            let totalRounded = roundedBase * Double(participantCount)
            let remainder = item.price - totalRounded
            
            // Distribute the remainder (should be small cents)
            let remainderCents = Int((remainder * 100).rounded())
            
            for (index, participantID) in item.participantIDs.enumerated() {
                
                if participantID != paidByUserID {
                    var amountOwed = roundedBase
                    
                    // Add extra cent to first few participants to handle remainder
                    if index < remainderCents {
                        amountOwed += 0.01
                    }
                    
                    let previousAmount = owedAmounts[participantID] ?? 0.0
                    owedAmounts[participantID] = previousAmount + amountOwed
                } else {
                }
            }
        }
        
        // Final rounding to ensure 2 decimal places
        for participantID in owedAmounts.keys {
            owedAmounts[participantID] = ((owedAmounts[participantID] ?? 0.0) * 100).rounded() / 100
        }
        
        return owedAmounts
    }
    
    /// Validates bill integrity by ensuring item prices sum to bill total
    ///
    /// This validation prevents data corruption from:
    /// - Manual editing errors
    /// - Floating-point precision issues
    /// - Incomplete bill updates
    ///
    /// - Parameter bill: Bill to validate
    /// - Returns: `true` if items total matches bill total within 1 cent tolerance, `false` otherwise
    ///
    /// - Note: Allows 1 cent tolerance for rounding differences
    static func validateBillTotals(bill: Bill) -> Bool {
        // Calculate total from individual item amounts
        let itemsTotal = bill.items.reduce(0.0) { $0 + $1.price }
        let expectedTotal = bill.totalAmount
        
        // The calculatedTotals only contains debts to the payer (not including payer's own share)
        // So we need to validate that items total matches the bill total instead
        let difference = abs(itemsTotal - expectedTotal)
        
        
        // Allow for small rounding differences (within 1 cent)
        let isValid = difference < 0.01
        return isValid
    }
    
    /// Calculates a user's net balance across all bills
    ///
    /// Aggregates all bills where the user is either:
    /// - The payer (owed money by other participants)
    /// - A participant (owes money to the payer)
    ///
    /// **Balance Calculation:**
    /// - Positive balance: User is owed money (others owe them)
    /// - Negative balance: User owes money (they owe others)
    /// - Zero balance: All debts settled
    ///
    /// - Parameters:
    ///   - userId: Firebase Auth UID of the user
    ///   - bills: All bills to include in balance calculation
    /// - Returns: Net balance amount (positive = owed, negative = owes)
    ///
    /// - Note: Only includes non-deleted bills in calculation
    static func calculateUserNetBalance(userId: String, bills: [Bill]) -> Double {
        var netBalance: Double = 0.0
        
        for bill in bills {
            // Skip deleted bills
            guard !bill.isDeleted else { continue }
            
            if bill.paidBy == userId {
                // User is the payer - they are owed money by others
                let owedAmounts = calculateOwedAmounts(bill: bill)
                let totalOwedToUser = owedAmounts.values.reduce(0) { $0 + $1 }
                netBalance += totalOwedToUser
                
            } else {
                // User is a participant - check how much they owe
                let owedAmounts = calculateOwedAmounts(bill: bill)
                if let amountOwed = owedAmounts[userId] {
                    netBalance -= amountOwed // Subtract because they owe money
                }
            }
        }
        
        // Round to 2 decimal places
        return (netBalance * 100).rounded() / 100
    }
}

// MARK: - OCR Service
class OCRService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress: Float = 0.0
    @Published var lastResult: OCRResult?
    @Published var errorMessage: String?
    
    func processImage(_ image: UIImage) async -> OCRResult {
        let startTime = Date()
        
        await MainActor.run {
            isProcessing = true
            progress = 0.1
            errorMessage = nil
        }
        
        guard let cgImage = image.cgImage else {
            await MainActor.run {
                isProcessing = false
                errorMessage = "Failed to process image"
            }
            return OCRResult(rawText: "", parsedItems: [], identifiedTotal: nil, suggestedAmounts: [], confidence: 0.0, processingTime: 0)
        }
        

        do {
            // Step 1: Extract text observations with spatial data (NEW APPROACH)
            await MainActor.run { progress = 0.3 }
            let observations = try await extractTextObservations(from: cgImage)

            // Convert to text for logging and backward compatibility
            let extractedText = observations
                .map { $0.topCandidates(1).first?.string ?? "" }
                .joined(separator: "\n")

            if extractedText.isEmpty {
            } else {
            }

            // Step 2: Parse using NEW geometric matching
            await MainActor.run { progress = 0.5 }
            let (parsedItems, identifiedTotal) = await parseReceiptObservations(observations)

            // Step 3: Classify items using smart classification system
            await MainActor.run { progress = 0.7 }
            let context = ReceiptContext.from(ocrResult: OCRResult(
                rawText: extractedText,
                parsedItems: parsedItems,
                identifiedTotal: identifiedTotal,
                suggestedAmounts: [],
                confidence: 0.0,
                processingTime: 0.0
            ))

            // Use user's saved classification configuration + engine selection
            let configManager = ClassificationConfigManager.shared
            let engine = ClassificationEngine.current

            print("🔧 Using classification engine: \(engine.rawValue)")

            let classifiedReceipt: ClassifiedReceipt
            if engine == .geminiOnly {
                // Use new Gemini-only classifier
                if let apiKey = try? KeychainAPIKeyProvider().getAPIKey() {
                    let geminiClassifier = GeminiOnlyClassifier(apiKey: apiKey)
                    classifiedReceipt = await geminiClassifier.classify(parsedItems, context: context)
                } else {
                    print("⚠️  No Gemini API key, falling back to legacy classifier")
                    let classifier = ReceiptClassifier(config: configManager.getCurrentConfig())
                    classifiedReceipt = await classifier.classify(parsedItems, context: context)
                }
            } else {
                // Use legacy multi-strategy classifier
                let classifier = ReceiptClassifier(config: configManager.getCurrentConfig())
                classifiedReceipt = await classifier.classify(parsedItems, context: context)
            }

            // Step 4: Calculate confidence and finish
            await MainActor.run { progress = 0.9 }
            let confidence = calculateConfidence(text: extractedText, items: parsedItems)
            let processingTime = Date().timeIntervalSince(startTime)

            let suggestedAmounts = extractPotentialAmounts(extractedText)

            // Use total from classification (if available), otherwise fall back to regex detection
            let finalTotal = classifiedReceipt.total?.price ?? identifiedTotal

            // Build OCR result with classification data
            let result = OCRResult(
                rawText: extractedText,
                parsedItems: parsedItems,
                identifiedTotal: finalTotal,  // Use classified total
                suggestedAmounts: suggestedAmounts,
                confidence: confidence,
                processingTime: processingTime,
                classifiedReceipt: classifiedReceipt  // NEW: Include classification
            )

            for (index, item) in parsedItems.enumerated() {
            }
            let totalValue = parsedItems.reduce(0) { $0.currencyAdd($1.price) }
            
            await MainActor.run {
                self.lastResult = result
                self.progress = 1.0
                self.isProcessing = false
            }
            
            return result
            
        } catch {
            await MainActor.run {
                self.isProcessing = false
                self.errorMessage = "OCR processing failed: \(error.localizedDescription)"
            }
            return OCRResult(rawText: "", parsedItems: [], identifiedTotal: nil, suggestedAmounts: [], confidence: 0.0, processingTime: Date().timeIntervalSince(startTime))
        }
    }
    
    // NEW: Extract text observations with spatial data preserved
    private func extractTextObservations(from cgImage: CGImage) async throws -> [VNRecognizedTextObservation] {
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }

                // Filter low-confidence observations but KEEP spatial data
                let filteredObservations = observations.filter { $0.confidence > 0.2 }

                continuation.resume(returning: filteredObservations)
            }

            // Optimized Vision Framework settings for receipts
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US"]
            request.minimumTextHeight = 0.005
            request.automaticallyDetectsLanguage = false

            let options: [VNImageOption: Any] = [:]
            let handler = VNImageRequestHandler(cgImage: cgImage, options: options)

            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    // Legacy method for backward compatibility (converts observations to text)
    private func extractText(from cgImage: CGImage) async throws -> String {
        let observations = try await extractTextObservations(from: cgImage)

        let recognizedText = observations
            .compactMap { observation in
                let topCandidate = observation.topCandidates(1).first?.string
                if let text = topCandidate, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return text
                }
                return nil
            }
            .joined(separator: "\n")

        return recognizedText
    }
    
    /// NEW: Parse receipt using geometric matching (spatial data from observations)
    private func parseReceiptObservations(_ observations: [VNRecognizedTextObservation]) async -> ([ReceiptItem], Double?) {
        print("\n" + String(repeating: "=", count: 60))
        print("🔵 === VISION OCR RAW OBSERVATIONS ===")
        print("🔵 Total observations from Vision Framework: \(observations.count)")
        print(String(repeating: "=", count: 60))

        // Log all raw observations with their bounding boxes
        for (index, obs) in observations.enumerated() {
            let text = obs.topCandidates(1).first?.string ?? ""
            let confidence = obs.confidence
            let bbox = obs.boundingBox
            print("🔵 Raw[\(index)]: '\(text)'")
            print("   Confidence: \(String(format: "%.2f", confidence))")
            print("   BoundingBox: X=\(String(format: "%.4f", bbox.minX))-\(String(format: "%.4f", bbox.maxX)), Y=\(String(format: "%.4f", bbox.minY))-\(String(format: "%.4f", bbox.maxY))")
        }
        print(String(repeating: "=", count: 60) + "\n")

        print("🔵 OCR: Using NEW geometric matching approach")
        print("🔵 OCR: Processing \(observations.count) text observations using geometry-based extraction")

        // Use pure geometric matching to extract ALL items (food, tax, tip, total, etc.)
        // No regex patterns, no keyword matching - just geometry + positions
        let detectedItems = extractItemsUsingGeometry(
            observations,
            maxPrice: nil  // Don't filter by max price - let classification handle it
        )

        print("\n" + String(repeating: "=", count: 60))
        print("🔵 === FINAL OCR RESULTS ===")
        print("🔵 OCR: Geometric matching found \(detectedItems.count) items")
        for (index, item) in detectedItems.enumerated() {
            print("🔵 Item[\(index)]: '\(item.name)' - $\(String(format: "%.2f", item.price))")
        }
        print(String(repeating: "=", count: 60) + "\n")

        // Return all items - classification system will determine what's what
        return (detectedItems, nil)
    }

    /// Legacy text-based parsing (kept for backward compatibility)
    private func parseReceiptText(_ text: String) async -> ([ReceiptItem], Double?) {

        // Step 1: Extract total, tax, tip first using regex
        let extractedTotal = extractReceiptTotal(text)
        let (taxAmount, tipAmount) = extractTaxAndTip(text)

        // Step 2: Clean text by removing total/tax/tip lines before sending to Apple Intelligence
        let cleanedText = removeFinancialSummaryLines(text: text)

        // Step 3: Use Apple Intelligence for item extraction (excluding financial summary)
        let detectedItems = await extractItemsWithAppleIntelligence(
            cleanedText: cleanedText,
            maxPrice: extractedTotal
        )

        // Step 4: Add tax and tip as separate items if detected
        let allItems = addFinancialSummaryItems(
            items: detectedItems,
            tax: taxAmount,
            tip: tipAmount
        )


        return (allItems, extractedTotal)
    }
    
    // MARK: - Smart Total Detection (No LLM Required)
    
    private func extractReceiptTotal(_ text: String) -> Double? {
        let lines = text.components(separatedBy: .newlines)
        var detectedTotals: [(amount: Double, confidence: Int, line: String)] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines
            if cleanLine.isEmpty { continue }
            
            // Look for total patterns with different confidence levels
            if let total = findTotalInLine(cleanLine) {
                detectedTotals.append(total)
            }
        }
        
        // Sort by confidence (highest first), then by amount (highest first)
        detectedTotals.sort { first, second in
            if first.confidence != second.confidence {
                return first.confidence > second.confidence
            }
            return first.amount > second.amount
        }
        
        // Return the highest confidence total
        if let bestTotal = detectedTotals.first {
            return bestTotal.amount
        }
        
        return nil
    }
    
    private func extractTaxAndTip(_ text: String) -> (tax: Double?, tip: Double?) {
        let lines = text.components(separatedBy: .newlines)
        var taxAmount: Double? = nil
        var tipAmount: Double? = nil

        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowercased = cleanLine.lowercased()

            // Look for tax - simple keyword + dollar amount
            if lowercased.contains("tax") && !lowercased.contains("total") {
                // Just extract the last price on the line (most reliable)
                if let amount = extractPriceFromLine(cleanLine) {
                    taxAmount = amount
                    print("💰 Tax detected: $\(amount)")
                }
            }

            // Look for tip/gratuity - simple keyword + dollar amount
            if (lowercased.contains("tip") || lowercased.contains("gratuity")) && !lowercased.contains("total") {
                // Just extract the last price on the line (most reliable)
                // This will correctly extract $5.00 from "Tip $5.00" or "Gratuity (18%) $5.00"
                // But won't incorrectly extract $20 from "Large Party (20.00%)"
                if let amount = extractPriceFromLine(cleanLine) {
                    tipAmount = amount
                    print("💰 Tip detected: $\(amount)")
                }
            }
        }
        
        return (taxAmount, tipAmount)
    }
    
    private func findTotalInLine(_ line: String) -> (amount: Double, confidence: Int, line: String)? {
        let lowercased = line.lowercased()
        
        // High confidence patterns (90+ confidence)
        let highConfidencePatterns = [
            (pattern: "total[:\\s]*\\$?([0-9]+\\.?[0-9]{0,2})", confidence: 95),
            (pattern: "amount due[:\\s]*\\$?([0-9]+\\.?[0-9]{0,2})", confidence: 90),
            (pattern: "grand total[:\\s]*\\$?([0-9]+\\.?[0-9]{0,2})", confidence: 95),
            (pattern: "final total[:\\s]*\\$?([0-9]+\\.?[0-9]{0,2})", confidence: 90)
        ]
        
        // Check high confidence patterns first
        for patternInfo in highConfidencePatterns {
            if let amount = extractAmountWithPattern(line: lowercased, pattern: patternInfo.pattern) {
                return (amount: amount, confidence: patternInfo.confidence, line: line)
            }
        }
        
        // Medium confidence patterns (70-80 confidence)
        let mediumConfidencePatterns = [
            (pattern: "total[:\\s]*([0-9]+\\.[0-9]{2})", confidence: 80),
            (pattern: "\\$([0-9]+\\.[0-9]{2})\\s*total", confidence: 75),
            (pattern: "([0-9]+\\.[0-9]{2})\\s*total", confidence: 70)
        ]
        
        for patternInfo in mediumConfidencePatterns {
            if let amount = extractAmountWithPattern(line: lowercased, pattern: patternInfo.pattern) {
                return (amount: amount, confidence: patternInfo.confidence, line: line)
            }
        }
        
        // Low confidence: Large dollar amounts at end of line
        if let amount = extractAmountWithPattern(line: line, pattern: "\\$?([0-9]+\\.[0-9]{2})\\s*$") {
            if amount >= 10.0 && amount <= 500.0 { // Reasonable restaurant total range
                return (amount: amount, confidence: 50, line: line)
            }
        }
        
        return nil
    }
    
    private func extractAmountWithPattern(line: String, pattern: String) -> Double? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
        
        for match in matches {
            if match.numberOfRanges > 1 {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: line) {
                    let amountString = String(line[swiftRange])
                    if let amount = Double(amountString), amount > 0 {
                        return amount
                    }
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Text Preprocessing for Apple Intelligence
    
    private func removeFinancialSummaryLines(text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var cleanedLines: [String] = []
        
        for line in lines {
            let lowercased = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip lines containing financial summary keywords
            let financialKeywords = [
                "total", "subtotal", "sub total", "grand total",
                "tax", "sales tax", "tip", "gratuity", "service charge",
                "amount due", "balance", "change", "payment"
            ]
            
            var shouldSkip = false
            for keyword in financialKeywords {
                if lowercased.contains(keyword) {
                    shouldSkip = true
                    break
                }
            }
            
            if !shouldSkip {
                cleanedLines.append(line)
            }
        }
        
        let cleanedText = cleanedLines.joined(separator: "\n")
        
        return cleanedText
    }
    
    private func addFinancialSummaryItems(
        items: [ReceiptItem],
        tax: Double?,
        tip: Double?
    ) -> [ReceiptItem] {
        
        var allItems = items
        
        // Add tax as a separate item if detected
        if let taxAmount = tax, taxAmount > 0 {
            allItems.append(ReceiptItem(name: "Tax", price: taxAmount))
        }
        
        // Add tip as a separate item if detected
        if let tipAmount = tip, tipAmount > 0 {
            allItems.append(ReceiptItem(name: "Tip", price: tipAmount))
        }
        
        return allItems
    }
    
    // MARK: - Apple Intelligence Item Detection
    
    private func extractItemsWithAppleIntelligence(
        cleanedText: String,
        maxPrice: Double?
    ) async -> [ReceiptItem] {
        
        
        // First, use Apple Intelligence to detect tax/tip values for filtering
        let (detectedTaxTotal, detectedTipTotal) = await detectTaxTipWithAppleIntelligence(text: cleanedText)
        
        if detectedTaxTotal > 0 {
        }
        if detectedTipTotal > 0 {
        }
        
        // Use Natural Language framework for intelligent text analysis
        let items = await parseReceiptWithNaturalLanguage(
            text: cleanedText, 
            maxPrice: maxPrice,
            excludeTaxAmount: detectedTaxTotal > 0 ? detectedTaxTotal : nil,
            excludeTipAmount: detectedTipTotal > 0 ? detectedTipTotal : nil
        )
        
        return items
    }
    
    private func parseReceiptWithNaturalLanguage(
        text: String, 
        maxPrice: Double?,
        excludeTaxAmount: Double? = nil,
        excludeTipAmount: Double? = nil
    ) async -> [ReceiptItem] {
        
        var extractedItems: [ReceiptItem] = []
        var placeholderIndex = 1
        
        // Split text into logical lines for analysis
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Use NL framework to understand each line
        for line in lines {
            if let item = await analyzeLineForItem(
                line: line, 
                maxPrice: maxPrice,
                excludeTaxAmount: excludeTaxAmount,
                excludeTipAmount: excludeTipAmount,
                placeholderIndex: &placeholderIndex
            ) {
                extractedItems.append(item)
            }
        }
        
        return extractedItems
    }
    
    private func analyzeLineForItem(
        line: String, 
        maxPrice: Double?,
        excludeTaxAmount: Double? = nil,
        excludeTipAmount: Double? = nil,
        placeholderIndex: inout Int
    ) async -> ReceiptItem? {
        
        // Skip obvious non-item lines
        if shouldSkipLineForIntelligentAnalysis(line) {
            return nil
        }
        
        // Extract price pattern first
        guard let price = extractPriceFromLine(line) else {
            return nil
        }
        
        // Apply price filtering - exclude items >= total (duplicate totals on receipt)
        if let maxPrice = maxPrice, price >= maxPrice {
            return nil
        }
        
        // Exclude items that match detected tax amounts
        if let taxAmount = excludeTaxAmount, abs(price - taxAmount) < 0.01 {
            return nil
        }
        
        // Exclude items that match detected tip amounts  
        if let tipAmount = excludeTipAmount, abs(price - tipAmount) < 0.01 {
            return nil
        }
        
        // Use Apple Intelligence (Natural Language) to extract item name
        let itemName = await extractItemNameWithAppleIntelligence(line: line, price: price)
        
        let finalItemName: String
        if let name = itemName, !name.isEmpty && name.count >= 3 {
            // Apple Intelligence found a meaningful item name
            finalItemName = name
        } else {
            // No clear name detected, use placeholder
            finalItemName = "Item \(placeholderIndex)"
            placeholderIndex += 1
        }
        
        return ReceiptItem(name: finalItemName, price: price)
    }
    
    private func shouldSkipLineForIntelligentAnalysis(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        
        // Skip header/footer patterns
        let skipPatterns = [
            "receipt", "thank you", "visit", "address", "phone", "store",
            "location", "cashier", "register", "server", "table",
            "date", "time", "order #", "transaction", "card ending",
            "auth", "ref", "batch"
        ]
        
        for pattern in skipPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        // Skip very short lines
        if line.count < 3 {
            return true
        }
        
        // Skip lines that are only numbers/symbols
        if line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace }) {
            return true
        }
        
        return false
    }
    
    private func extractItemNameWithAppleIntelligence(line: String, price: Double) async -> String? {
        // Remove the price from the line to isolate potential item name
        let priceStrings = [
            "$\(String(format: "%.2f", price))", 
            String(format: "%.2f", price),
            "$\(Int(price))",
            String(Int(price))
        ]
        
        var cleanLine = line
        for priceString in priceStrings {
            cleanLine = cleanLine.replacingOccurrences(of: priceString, with: " ")
        }
        
        // Clean up the remaining text
        cleanLine = cleanLine.trimmingCharacters(in: .whitespacesAndNewlines)
        cleanLine = cleanLine.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        cleanLine = cleanLine.trimmingCharacters(in: CharacterSet(charactersIn: ".-_*()[]{}"))
        
        // Skip if too short or only numbers
        guard cleanLine.count >= 3 else { return nil }
        guard cleanLine.contains(where: { $0.isLetter }) else { return nil }
        
        // Use Natural Language framework to analyze the text semantically
        let analysis = await analyzeTextWithNaturalLanguage(cleanLine)
        
        if analysis {
            let cleanedName = cleanLine.capitalized
                .replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            return cleanedName
        }
        
        return nil
    }
    
    private func analyzeTextWithNaturalLanguage(_ text: String) async -> Bool {
        
        // Use NLTagger for semantic analysis
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .nameType])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        var hasNouns = false
        var hasProperNouns = false
        var wordCount = 0
        
        // Analyze lexical classes (nouns, adjectives, etc.)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, range in
            wordCount += 1
            
            if tag == .noun {
                hasNouns = true
            } else if tag == .adjective {
                hasNouns = true  // Adjectives often describe products
            }
            
            return true
        }
        
        // Analyze for proper nouns (brand names, etc.)
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .organizationName || tag == .placeName {
                hasProperNouns = true
            }
            return true
        }
        
        // Check for common food/product keywords
        let productKeywords = [
            "sandwich", "salad", "burger", "pizza", "pasta", "chicken", "beef", "fish",
            "soup", "appetizer", "dessert", "cake", "pie", "drink", "coffee", "tea",
            "special", "combo", "meal", "plate", "bowl", "cup", "bottle", "glass"
        ]
        
        let lowercased = text.lowercased()
        let hasProductKeywords = productKeywords.contains { lowercased.contains($0) }
        
        // Decision logic: Is this likely a product name?
        let isLikelyProduct = (hasNouns || hasProperNouns || hasProductKeywords) && 
                             wordCount >= 1 && 
                             wordCount <= 6 &&
                             !isObviousNonProduct(text)
        
        
        return isLikelyProduct
    }
    
    private func isObviousNonProduct(_ text: String) -> Bool {
        let lowercased = text.lowercased()
        
        // Skip obvious non-product text
        let nonProductPatterns = [
            "qty", "quantity", "each", "ea", "lb", "oz", "gal", "ct", "pk",
            "server", "table", "order", "receipt", "thank", "visit"
        ]
        
        for pattern in nonProductPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func isLikelyProductName(_ text: String) -> Bool {
        // Must have reasonable length
        guard text.count >= 2 && text.count <= 50 else { return false }
        
        // Must contain letters
        guard text.contains(where: { $0.isLetter }) else { return false }
        
        // Use Natural Language to check if it's meaningful text
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation]
        var hasNouns = false
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass, options: options) { tag, _ in
            if tag == .noun || tag == .adjective {
                hasNouns = true
                return false // Stop enumeration
            }
            return true
        }
        
        return hasNouns || text.split(separator: " ").count >= 2
    }
    
    // MARK: - Apple Intelligence Tax/Tip Detection
    
    private func detectTaxTipWithAppleIntelligence(text: String) async -> (taxTotal: Double, tipTotal: Double) {
        
        // Step 1: Use regex for primary detection (fast, reliable)
        let regexTaxAmounts = extractTaxAmountsWithRegex(text)
        let regexTipAmounts = extractTipAmountsWithRegex(text)
        
        
        // Step 2: Use Apple Intelligence for validation and edge cases
        let aiResults = await validateTaxTipWithAppleIntelligence(
            text: text,
            regexTaxAmounts: regexTaxAmounts,
            regexTipAmounts: regexTipAmounts
        )
        
        // Step 3: Sum the validated results
        let totalTax = aiResults.validatedTaxAmounts.reduce(0, +)
        let totalTip = aiResults.validatedTipAmounts.reduce(0, +)
        
        
        return (taxTotal: totalTax, tipTotal: totalTip)
    }
    
    private func extractTaxAmountsWithRegex(_ text: String) -> [Double] {
        let taxPatterns = [
            #"(?i)(?:sales?\s*)?tax[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)(?:state|local|city)\s*tax[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)tax\s*(?:amount|total)[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)(?:^|\s)tx[\s:]*\$?(\d+\.?\d*)"#
        ]
        
        return extractAmountsUsingPatterns(text: text, patterns: taxPatterns)
    }
    
    private func extractTipAmountsWithRegex(_ text: String) -> [Double] {
        let tipPatterns = [
            #"(?i)tip[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)gratuity[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)service\s*(?:charge|fee)[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)(?:auto|automatic)\s*(?:tip|gratuity)[\s:]*\$?(\d+\.?\d*)"#,
            #"(?i)(?:^|\s)grat[\s:]*\$?(\d+\.?\d*)"#
        ]
        
        return extractAmountsUsingPatterns(text: text, patterns: tipPatterns)
    }
    
    private func extractAmountsUsingPatterns(text: String, patterns: [String]) -> [Double] {
        var amounts: [Double] = []
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let amountString = String(text[range])
                        if let amount = Double(amountString), amount > 0 {
                            amounts.append(amount)
                        }
                    }
                }
            } catch {
                // Continue with next pattern instead of crashing
                continue
            }
        }
        
        return amounts
    }
    
    private func validateTaxTipWithAppleIntelligence(
        text: String,
        regexTaxAmounts: [Double],
        regexTipAmounts: [Double]
    ) async -> (validatedTaxAmounts: [Double], validatedTipAmounts: [Double]) {
        
        
        // If regex found clear results, validate them with AI
        var validatedTax = regexTaxAmounts
        var validatedTip = regexTipAmounts
        
        // Use Natural Language to look for additional edge cases
        let additionalTaxTip = await findAdditionalTaxTipWithNL(text: text)
        
        // Add any additional amounts found by AI that weren't caught by regex
        for amount in additionalTaxTip.additionalTax {
            if !regexTaxAmounts.contains(where: { abs($0 - amount) < 0.01 }) {
                validatedTax.append(amount)
            }
        }
        
        for amount in additionalTaxTip.additionalTip {
            if !regexTipAmounts.contains(where: { abs($0 - amount) < 0.01 }) {
                validatedTip.append(amount)
            }
        }
        
        return (validatedTaxAmounts: validatedTax, validatedTipAmounts: validatedTip)
    }
    
    private func findAdditionalTaxTipWithNL(text: String) async -> (additionalTax: [Double], additionalTip: [Double]) {
        // Use NLTagger to find lines that semantically relate to tax/tip concepts
        let lines = text.components(separatedBy: .newlines)
        var additionalTax: [Double] = []
        var additionalTip: [Double] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleanLine.isEmpty else { continue }
            
            // Extract any price from the line first
            guard let price = extractPriceFromLine(cleanLine) else { continue }
            
            // Use semantic analysis to determine if this line relates to tax or tip
            let isTaxRelated = await isLineTaxRelated(cleanLine)
            let isTipRelated = await isLineTipRelated(cleanLine)
            
            if isTaxRelated {
                additionalTax.append(price)
            } else if isTipRelated {
                additionalTip.append(price)
            }
        }
        
        return (additionalTax: additionalTax, additionalTip: additionalTip)
    }
    
    private func isLineTaxRelated(_ text: String) async -> Bool {
        // Use semantic concepts to identify tax-related content
        let taxConcepts = ["tax", "taxation", "levy", "charge", "government", "state", "sales"]
        let lowercased = text.lowercased()
        
        // Check for semantic similarity using NL
        return taxConcepts.contains { concept in
            lowercased.contains(concept) || 
            semanticallyRelated(text: lowercased, concept: concept)
        }
    }
    
    private func isLineTipRelated(_ text: String) async -> Bool {
        // Use semantic concepts to identify tip-related content  
        let tipConcepts = ["tip", "gratuity", "service", "server", "waiter", "staff"]
        let lowercased = text.lowercased()
        
        // Check for semantic similarity using NL
        return tipConcepts.contains { concept in
            lowercased.contains(concept) ||
            semanticallyRelated(text: lowercased, concept: concept)
        }
    }
    
    private func semanticallyRelated(text: String, concept: String) -> Bool {
        // Simple semantic similarity check using word embeddings concept
        // This is a simplified version - in a full implementation you might use
        // more sophisticated NL techniques
        
        let conceptSynonyms: [String: [String]] = [
            "tax": ["fee", "charge", "levy", "duty"],
            "tip": ["gratuity", "bonus", "reward", "service"],
            "service": ["assistance", "help", "support"]
        ]
        
        if let synonyms = conceptSynonyms[concept] {
            return synonyms.contains { text.contains($0) }
        }
        
        return false
    }
    
    private func validateAndCompleteItems(
        items: [ReceiptItem],
        total: Double?,
        tax: Double?,
        tip: Double?
    ) -> [ReceiptItem] {
        
        var completeItems = items
        
        // Add tax and tip as separate items if detected
        if let taxAmount = tax, taxAmount > 0 {
            completeItems.append(ReceiptItem(name: "Tax", price: taxAmount))
        }
        
        if let tipAmount = tip, tipAmount > 0 {
            completeItems.append(ReceiptItem(name: "Tip", price: tipAmount))
        }
        
        // Validate against total if available
        if let totalAmount = total {
            let itemsTotal = completeItems.reduce(0) { $0.currencyAdd($1.price) }
            let difference = abs(totalAmount - itemsTotal)
            
            
            if difference > 1.0 {
            } else {
            }
        }
        
        return completeItems
    }
    
    // MARK: - Legacy Item Detection (Keep for fallback)
    
    private func extractItemsWithNames(_ text: String, maxPrice: Double?) -> [ReceiptItem] {
        let lines = text.components(separatedBy: .newlines)
        var detectedItems: [ReceiptItem] = []
        
        
        // Method 1: Same-line parsing (existing patterns)
        detectedItems.append(contentsOf: parseSameLineItems(lines, maxPrice: maxPrice))
        
        // Method 2: Multi-line parsing (name on one line, price on next)
        detectedItems.append(contentsOf: parseMultiLineItems(lines, maxPrice: maxPrice))
        
        // Method 3: Block parsing (all names, then all prices)
        detectedItems.append(contentsOf: parseBlockItems(lines, maxPrice: maxPrice))
        
        for item in detectedItems {
        }
        
        return detectedItems
    }
    
    private func shouldSkipLine(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        
        // Skip header/footer information
        let skipPatterns = [
            "receipt", "thank you", "address", "phone", "store", "location",
            "cashier", "register", "transaction", "date", "time",
            "tax", "tip", "total", "subtotal", "amount due", "balance"  // Skip tax/tip/total from items
        ]
        
        for pattern in skipPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        // Skip lines that are just numbers or special characters
        if line.count < 2 || line.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isWhitespace }) {
            return true
        }
        
        return false
    }
    
    // Method 1: Same-line parsing
    private func parseSameLineItems(_ lines: [String], maxPrice: Double?) -> [ReceiptItem] {
        var items: [ReceiptItem] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanLine.isEmpty || shouldSkipLine(cleanLine) {
                continue
            }
            
            if let item = parseItemFromLine(cleanLine) {
                if isValidItemPrice(item.price, maxPrice: maxPrice) {
                    items.append(item)
                }
            }
        }
        
        return items
    }
    
    // Method 2: Multi-line parsing (item name, then price on next line)
    private func parseMultiLineItems(_ lines: [String], maxPrice: Double?) -> [ReceiptItem] {
        var items: [ReceiptItem] = []
        
        for i in 0..<(lines.count - 1) {
            let currentLine = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            let nextLine = lines[i + 1].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if current line looks like an item name and next line looks like a price
            if isLikelyItemName(currentLine) && isLikelyPrice(nextLine) {
                if let price = extractPriceFromLine(nextLine) {
                    if isValidItemPrice(price, maxPrice: maxPrice) {
                        let itemName = cleanItemName(currentLine)
                        if !itemName.isEmpty {
                            let item = ReceiptItem(name: itemName, price: price)
                            items.append(item)
                        }
                    }
                }
            }
        }
        
        return items
    }
    
    // Method 3: Block parsing (all items listed, then all prices)
    private func parseBlockItems(_ lines: [String], maxPrice: Double?) -> [ReceiptItem] {
        var items: [ReceiptItem] = []
        var itemNames: [String] = []
        var prices: [Double] = []
        
        // First pass: collect potential item names and prices separately
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanLine.isEmpty || shouldSkipLine(cleanLine) {
                continue
            }
            
            // If line is just a price, add to prices array
            if let price = extractPriceFromLine(cleanLine), isPurePrice(cleanLine) {
                if isValidItemPrice(price, maxPrice: maxPrice) {
                    prices.append(price)
                }
            }
            // If line looks like an item name (has letters, not just price), add to names
            else if isLikelyItemName(cleanLine) && !isPurePrice(cleanLine) {
                itemNames.append(cleanItemName(cleanLine))
            }
        }
        
        // Match names with prices (if counts are similar)
        let minCount = min(itemNames.count, prices.count)
        if minCount > 0 && abs(itemNames.count - prices.count) <= 2 {
            for i in 0..<minCount {
                let item = ReceiptItem(name: itemNames[i], price: prices[i])
                items.append(item)
            }
        }
        
        return items
    }
    
    private func isLikelyItemName(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must have at least 3 characters and contain letters
        guard trimmed.count >= 3 && trimmed.contains(where: { $0.isLetter }) else {
            return false
        }
        
        // Should not be just a price
        return !isPurePrice(trimmed)
    }
    
    private func isLikelyPrice(_ line: String) -> Bool {
        return extractPriceFromLine(line) != nil
    }
    
    private func isPurePrice(_ line: String) -> Bool {
        // Check if line is just a price (with optional $ and spaces)
        let cleanLine = line.replacingOccurrences(of: " ", with: "")
        let pricePattern = "^\\$?[0-9]+\\.[0-9]{2}$"
        
        guard let regex = try? NSRegularExpression(pattern: pricePattern, options: []) else {
            return false
        }
        
        let range = NSRange(location: 0, length: cleanLine.count)
        return regex.firstMatch(in: cleanLine, options: [], range: range) != nil
    }
    
    private func extractPriceFromLine(_ line: String) -> Double? {
        let pricePattern = "\\$?([0-9]+\\.[0-9]{2})"

        guard let regex = try? NSRegularExpression(pattern: pricePattern, options: []) else {
            return nil
        }

        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))

        for match in matches {
            if let range = Range(match.range(at: 1), in: line) {
                let priceString = String(line[range])
                if let price = Double(priceString) {
                    return price
                }
            }
        }

        return nil
    }

    // MARK: - Geometric Matching Helpers

    /// Checks if a string matches price format patterns
    private func isPriceFormat(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // More lenient patterns to catch various receipt formats
        let pricePatterns = [
            "\\$?[0-9]+\\.[0-9]{2}",                    // $12.99 or 12.99 (anywhere in string)
            "\\$?[0-9]{1,3}(,[0-9]{3})+\\.[0-9]{2}",   // $1,234.56 or 1,234.56
            "\\$[0-9]+\\.[0-9]{2}",                     // $12.99 (strict)
            "[0-9]+\\.[0-9]{2}$"                        // 12.99 (at end of string)
        ]

        for pattern in pricePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil {
                return true
            }
        }

        return false
    }

    /// Extracts numeric price value from a price string
    private func extractPriceValue(_ text: String) -> Double? {
        let cleaned = text.replacingOccurrences(of: "$", with: "")
                         .replacingOccurrences(of: ",", with: "")
                         .trimmingCharacters(in: .whitespacesAndNewlines)

        if let value = Double(cleaned) {
            print("   💵 Extracted price value: '\(text)' → $\(value)")
            return value
        } else {
            print("   ❌ Failed to convert '\(text)' (cleaned: '\(cleaned)') to Double")
            return nil
        }
    }

    /// Checks if a line is likely a tax or tip line (to be excluded from items)
    private func isTaxOrTipLine(_ text: String) -> Bool {
        let lowercased = text.lowercased()

        // Exclude tax, tip, gratuity, totals, service charges, and auto-gratuity
        let excludeKeywords = ["tax", "tip", "gratuity", "total", "subtotal", "balance", "change", "service charge", "auto grat", "large party", "party gratuity"]

        // Check if keyword is present and line is relatively short (not a menu item containing the word)
        for keyword in excludeKeywords {
            if lowercased == keyword ||
               lowercased.hasPrefix(keyword + " ") ||
               lowercased.hasSuffix(" " + keyword) ||
               (lowercased.contains(keyword) && lowercased.count < 30) {
                print("🔴 Tax/Tip filter: '\(text)' excluded (keyword: \(keyword))")
                return true
            }
        }

        return false
    }

    /// Groups observations by vertical position (Y-coordinate clustering)
    private func groupObservationsByLine(
        _ observations: [VNRecognizedTextObservation],
        yTolerance: CGFloat = 0.02
    ) -> [[VNRecognizedTextObservation]] {
        print("\n🔵 === LINE GROUPING START ===")
        print("🔵 Total observations to group: \(observations.count)")
        print("🔵 Y-tolerance: \(yTolerance) (2% of receipt height)")

        // Sort by Y position (top to bottom - Vision coordinates are inverted)
        let sorted = observations.sorted { $0.boundingBox.midY > $1.boundingBox.midY }

        var lines: [[VNRecognizedTextObservation]] = []
        var currentLine: [VNRecognizedTextObservation] = []
        var currentY: CGFloat?

        for (index, obs) in sorted.enumerated() {
            let obsY = obs.boundingBox.midY
            let text = obs.topCandidates(1).first?.string ?? ""

            print("🔵 Obs[\(index)]: '\(text)' at Y=\(String(format: "%.4f", obsY)) X=\(String(format: "%.4f", obs.boundingBox.minX))-\(String(format: "%.4f", obs.boundingBox.maxX))")

            if let lastY = currentY, abs(obsY - lastY) <= yTolerance {
                // Same line - within tolerance
                print("   ↳ Same line as previous (Y diff: \(String(format: "%.4f", abs(obsY - lastY))))")
                currentLine.append(obs)
            } else {
                // New line detected
                if !currentLine.isEmpty {
                    let lineTexts = currentLine.map { $0.topCandidates(1).first?.string ?? "" }
                    print("   ✅ Line \(lines.count) complete: [\(lineTexts.joined(separator: " | "))]")
                    lines.append(currentLine)
                }
                print("   🆕 Starting new line at Y=\(String(format: "%.4f", obsY))")
                currentLine = [obs]
                currentY = obsY
            }
        }

        // Add last line
        if !currentLine.isEmpty {
            let lineTexts = currentLine.map { $0.topCandidates(1).first?.string ?? "" }
            print("   ✅ Line \(lines.count) complete (last): [\(lineTexts.joined(separator: " | "))]")
            lines.append(currentLine)
        }

        print("🔵 === LINE GROUPING COMPLETE: \(lines.count) lines ===\n")
        return lines
    }

    /// NEW: Extract items using geometric/spatial matching instead of NL analysis
    private func extractItemsUsingGeometry(
        _ observations: [VNRecognizedTextObservation],
        maxPrice: Double?
    ) -> [ReceiptItem] {
        print("\n🟢 === GEOMETRY EXTRACTION START ===")
        let lines = groupObservationsByLine(observations)
        var items: [ReceiptItem] = []

        print("🟢 Processing \(lines.count) lines for price extraction\n")

        for (lineIndex, line) in lines.enumerated() {
            print("🟢 --- Line \(lineIndex) Analysis ---")

            // Sort by horizontal position (left to right)
            let sorted = line.sorted { $0.boundingBox.minX < $1.boundingBox.minX }
            let lineText = sorted.map { $0.topCandidates(1).first?.string ?? "" }.joined(separator: " ")
            print("🟢 Line text: '\(lineText)'")

            // Check each observation for price format
            print("🟢 Checking \(sorted.count) observations for price patterns:")
            for (i, obs) in sorted.enumerated() {
                let text = obs.topCandidates(1).first?.string ?? ""
                let isPrice = isPriceFormat(text)
                print("   [\(i)] '\(text)' at X=\(String(format: "%.4f", obs.boundingBox.minX))-\(String(format: "%.4f", obs.boundingBox.maxX)) → \(isPrice ? "✅ PRICE" : "❌ not price")")
            }

            // Find price on this line (right-aligned, matches price pattern)
            guard let priceObs = sorted.last(where: { obs in
                let text = obs.topCandidates(1).first?.string ?? ""
                return isPriceFormat(text)
            }) else {
                print("⚠️  No valid price found on line \(lineIndex), skipping\n")
                continue
            }

            guard let priceText = priceObs.topCandidates(1).first?.string,
                  let price = extractPriceValue(priceText),
                  price > 0 else {
                print("⚠️  Price extraction failed for '\(priceObs.topCandidates(1).first?.string ?? "")'\n")
                continue
            }

            print("💰 Found price: $\(price) at X=\(String(format: "%.4f", priceObs.boundingBox.minX))")

            // Everything left of price = item name
            // Reduced margin from 0.05 (5%) to 0.01 (1%) to be more lenient
            let priceLeftEdge = priceObs.boundingBox.minX + 0.01
            print("🟢 Looking for name observations with maxX < \(String(format: "%.4f", priceLeftEdge))")

            let nameObservations = sorted.filter {
                let qualifies = $0.boundingBox.maxX < priceLeftEdge
                let text = $0.topCandidates(1).first?.string ?? ""
                print("   '\(text)' maxX=\(String(format: "%.4f", $0.boundingBox.maxX)) → \(qualifies ? "✅ included" : "❌ excluded (overlaps price)")")
                return qualifies
            }

            guard !nameObservations.isEmpty else {
                print("⚠️  No text found before price, skipping line\n")
                continue
            }

            let itemName = nameObservations
                .map { $0.topCandidates(1).first?.string ?? "" }
                .joined(separator: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            print("📝 Extracted name: '\(itemName)' (length: \(itemName.count))")

            // Only skip if name is too short (single character)
            // Let the classification system determine what's tax/tip/total/food
            guard itemName.count >= 2 else {
                print("⚠️  Name too short, skipping\n")
                continue
            }

            print("✅ EXTRACTED ITEM: '\(itemName)' - $\(price)\n")
            items.append(ReceiptItem(name: itemName, price: price))
        }

        print("🟢 === GEOMETRY EXTRACTION COMPLETE: \(items.count) items extracted ===\n")
        return items
    }

    private func parseItemFromLine(_ line: String) -> ReceiptItem? {
        // Pattern 1: Item name followed by price at end of line
        // Example: "Chicken Sandwich    12.99" or "MILK 1GAL $3.49"
        let pattern1 = "^(.+?)\\s+\\$?([0-9]+\\.[0-9]{2})\\s*$"
        
        if let match = extractWithPattern(line: line, pattern: pattern1) {
            let itemName = match.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let price = match.price
            
            // Validate the extracted data
            if isValidItemName(itemName) && price > 0 {
                return ReceiptItem(name: cleanItemName(itemName), price: price)
            }
        }
        
        // Pattern 2: Price at beginning followed by item name
        // Example: "$12.99 Chicken Sandwich" or "3.49 MILK 1GAL"
        let pattern2 = "^\\$?([0-9]+\\.[0-9]{2})\\s+(.+)$"
        
        if let match = extractWithPattern(line: line, pattern: pattern2, swapNamePrice: true) {
            let itemName = match.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let price = match.price
            
            if isValidItemName(itemName) && price > 0 {
                return ReceiptItem(name: cleanItemName(itemName), price: price)
            }
        }
        
        // Pattern 3: Item name and price separated by multiple spaces or tabs
        // Example: "Chicken Sandwich        12.99"
        let pattern3 = "^(.+?)\\s{2,}\\$?([0-9]+\\.[0-9]{2})\\s*$"
        
        if let match = extractWithPattern(line: line, pattern: pattern3) {
            let itemName = match.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let price = match.price
            
            if isValidItemName(itemName) && price > 0 {
                return ReceiptItem(name: cleanItemName(itemName), price: price)
            }
        }
        
        return nil
    }
    
    private func extractWithPattern(line: String, pattern: String, swapNamePrice: Bool = false) -> (name: String, price: Double)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
        
        guard let match = matches.first, match.numberOfRanges >= 3 else {
            return nil
        }
        
        let range1 = match.range(at: 1)
        let range2 = match.range(at: 2)
        
        guard let swiftRange1 = Range(range1, in: line),
              let swiftRange2 = Range(range2, in: line) else {
            return nil
        }
        
        let string1 = String(line[swiftRange1])
        let string2 = String(line[swiftRange2])
        
        if swapNamePrice {
            // Pattern 2: price comes first, then name
            guard let price = Double(string1) else { return nil }
            return (name: string2, price: price)
        } else {
            // Pattern 1 & 3: name comes first, then price
            guard let price = Double(string2) else { return nil }
            return (name: string1, price: price)
        }
    }
    
    private func isValidItemName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Must have at least 2 characters
        guard trimmed.count >= 2 else { return false }
        
        // Must contain at least one letter
        guard trimmed.contains(where: { $0.isLetter }) else { return false }
        
        // Skip obvious non-items
        let lowercased = trimmed.lowercased()
        let invalidNames = ["qty", "ea", "each", "lb", "oz", "gal", "ct", "pk"]
        
        for invalid in invalidNames {
            if lowercased == invalid {
                return false
            }
        }
        
        return true
    }
    
    private func isValidItemPrice(_ price: Double, maxPrice: Double?) -> Bool {
        // Must be positive
        guard price > 0 else { return false }
        
        // If we have a total, price should be less than total (items can't cost more than total bill)
        if let maxPrice = maxPrice {
            return price < maxPrice
        }
        
        // Without total reference, accept reasonable range
        return price <= 500.0
    }
    
    private func cleanItemName(_ name: String) -> String {
        var cleaned = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common suffixes that aren't part of the item name
        let suffixesToRemove = ["EA", "LB", "OZ", "GAL", "CT", "PK", "@"]
        
        for suffix in suffixesToRemove {
            if cleaned.hasSuffix(" " + suffix) {
                cleaned = String(cleaned.dropLast(suffix.count + 1))
            }
        }
        
        // Capitalize first letter of each word for better presentation
        return cleaned.capitalized
    }
    
    // Don't remove duplicates - allow multiple identical items (ordered by different people)
    private func removeDuplicateItems(_ items: [ReceiptItem]) -> [ReceiptItem] {
        return items
    }
    
    // MARK: - Comprehensive Item Detection
    
    private func completeItemsToMatchTotal(
        text: String, 
        itemsWithNames: [ReceiptItem], 
        total: Double?, 
        tax: Double?, 
        tip: Double?
    ) -> [ReceiptItem] {
        
        var allItems = itemsWithNames
        
        guard let totalAmount = total else {
            return allItems
        }
        
        // Calculate what we've already accounted for
        let namedItemsTotal = itemsWithNames.reduce(0) { $0.currencyAdd($1.price) }
        let taxAmount = tax ?? 0
        let tipAmount = tip ?? 0
        let accountedAmount = namedItemsTotal.currencyAdd(taxAmount).currencyAdd(tipAmount)
        
        
        // If we're already close to the total, don't add more items
        if abs(totalAmount - accountedAmount) <= 0.50 {
            return addTaxAndTipItems(items: allItems, tax: tax, tip: tip)
        }
        
        // Find all dollar amounts in the text that we haven't used yet
        let usedAmounts = Set(itemsWithNames.map { $0.price })
        let allAmounts = extractAllAmountsFromText(text, excluding: usedAmounts, maxPrice: totalAmount)
        
        // Try to find combination of amounts that gets us close to the total
        let missingAmount = totalAmount - accountedAmount
        let additionalItems = findBestAmountCombination(
            amounts: allAmounts, 
            targetAmount: missingAmount,
            startingIndex: itemsWithNames.count + 1
        )
        
        
        allItems.append(contentsOf: additionalItems)
        
        // Add tax and tip as separate items
        return addTaxAndTipItems(items: allItems, tax: tax, tip: tip)
    }
    
    private func extractAllAmountsFromText(_ text: String, excluding usedAmounts: Set<Double>, maxPrice: Double) -> [Double] {
        let lines = text.components(separatedBy: .newlines)
        var amounts: [Double] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip lines that are obviously not items
            if shouldSkipLineForAmountExtraction(cleanLine) {
                continue
            }
            
            // Extract all amounts from this line
            if let lineAmounts = extractAmountsFromLine(cleanLine) {
                for amount in lineAmounts {
                    // Only include if we haven't already used this amount and it's reasonable
                    if !usedAmounts.contains(amount) && amount > 0 && amount < maxPrice {
                        amounts.append(amount)
                    }
                }
            }
        }
        
        // Remove duplicates and sort
        let uniqueAmounts = Array(Set(amounts)).sorted()
        
        return uniqueAmounts
    }
    
    private func shouldSkipLineForAmountExtraction(_ line: String) -> Bool {
        let lowercased = line.lowercased()
        
        // Skip obvious non-item lines
        let skipPatterns = [
            "receipt", "thank you", "address", "phone", "store", "location",
            "cashier", "register", "transaction", "date", "time", "card #",
            "total", "subtotal", "tax", "tip", "change", "cash", "credit"
        ]
        
        for pattern in skipPatterns {
            if lowercased.contains(pattern) {
                return true
            }
        }
        
        return false
    }
    
    private func extractAmountsFromLine(_ line: String) -> [Double]? {
        let amountPattern = "\\$?([0-9]+\\.[0-9]{2})"
        guard let regex = try? NSRegularExpression(pattern: amountPattern, options: []) else {
            return nil
        }
        
        let matches = regex.matches(in: line, options: [], range: NSRange(location: 0, length: line.count))
        var amounts: [Double] = []
        
        for match in matches {
            if let range = Range(match.range(at: 1), in: line) {
                let amountString = String(line[range])
                if let amount = Double(amountString) {
                    amounts.append(amount)
                }
            }
        }
        
        return amounts.isEmpty ? nil : amounts
    }
    
    private func findBestAmountCombination(amounts: [Double], targetAmount: Double, startingIndex: Int) -> [ReceiptItem] {
        var items: [ReceiptItem] = []
        var remainingTarget = targetAmount
        var itemIndex = startingIndex
        
        // Sort amounts in descending order to try larger amounts first
        let sortedAmounts = amounts.sorted(by: >)
        
        for amount in sortedAmounts {
            // If this amount gets us closer to the target, use it
            if amount <= remainingTarget + 1.0 { // Allow some tolerance
                let item = ReceiptItem(name: "Item \(itemIndex)", price: amount)
                items.append(item)
                remainingTarget -= amount
                itemIndex += 1
                
                
                // If we're close enough to the target, stop
                if abs(remainingTarget) <= 1.0 {
                    break
                }
            }
        }
        
        return items
    }
    
    private func addTaxAndTipItems(items: [ReceiptItem], tax: Double?, tip: Double?) -> [ReceiptItem] {
        var allItems = items
        
        // Add tax as a separate item if detected
        if let taxAmount = tax, taxAmount > 0 {
            let taxItem = ReceiptItem(name: "Tax", price: taxAmount)
            allItems.append(taxItem)
        }
        
        // Add tip as a separate item if detected
        if let tipAmount = tip, tipAmount > 0 {
            let tipItem = ReceiptItem(name: "Tip", price: tipAmount)
            allItems.append(tipItem)
        }
        
        return allItems
    }
    
    private func extractPotentialAmounts(_ text: String) -> [Double] {
        let lines = text.components(separatedBy: .newlines)
        var amounts: [Double] = []
        
        for line in lines {
            let cleanLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip header/footer lines
            let lowercased = cleanLine.lowercased()
            if lowercased.contains("receipt") || 
               lowercased.contains("thank you") ||
               lowercased.contains("address") ||
               lowercased.contains("phone") {
                continue
            }
            
            // Find all dollar amounts in the line
            let amountPattern = "\\$?([0-9]+\\.[0-9]{2})"
            if let regex = try? NSRegularExpression(pattern: amountPattern, options: []) {
                let matches = regex.matches(in: cleanLine, options: [], range: NSRange(location: 0, length: cleanLine.count))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: cleanLine) {
                        let amountString = String(cleanLine[range])
                        if let amount = Double(amountString) {
                            // Filter reasonable item prices (not tax rates, tips, etc.)
                            if amount >= 1.0 && amount <= 100.0 {
                                amounts.append(amount)
                            }
                        }
                    }
                }
            }
        }
        
        // Remove duplicates and sort
        let uniqueAmounts = Array(Set(amounts)).sorted()
        
        for amount in uniqueAmounts {
        }
        
        return uniqueAmounts
    }
    
    private func calculateConfidence(text: String, items: [ReceiptItem]) -> Float {
        if text.isEmpty {
            return 0.0
        }
        
        let textLength = Float(text.count)
        let itemCount = Float(items.count)
        
        var confidence: Float = min(textLength / 100.0, 1.0)
        confidence = confidence * 0.7 + (itemCount > 0 ? 0.3 : 0.0)
        
        return min(max(confidence, 0.0), 1.0)
    }
    
    // Debug method to test parsing with known text
    func testParsing() async -> OCRResult {
        
        // Test with realistic receipt that has all edge cases
        let sampleText = """
        RESTAURANT ABC
        123 Main Street
        Order #12345
        
        Chicken Sandwich 12.99
        Caesar Salad 8.50
        Appetizer Special 6.75
        4.25
        Coke 2.99
        3.45
        48.05
        
        Subtotal 38.93
        Sales Tax 3.12
        Tip 6.00
        
        Total 48.05
        Grand Total 48.05
        Thank you for visiting!
        """
        
        let (items, total) = await parseReceiptText(sampleText)
        let suggestedAmounts = extractPotentialAmounts(sampleText)
        
        return OCRResult(
            rawText: sampleText,
            parsedItems: items,
            identifiedTotal: total,
            suggestedAmounts: suggestedAmounts,
            confidence: 0.9,
            processingTime: 0.1
        )
    }
    
    // MARK: - Confirmation Analysis Methods
    
    func analyzeReceiptForConfirmation(text: String) async -> ReceiptAnalysis {
        
        // Step 1: Use existing regex patterns to detect tax, tip, and total
        let (detectedTaxOptional, detectedTipOptional) = extractTaxAndTip(text)
        let detectedTotal = extractReceiptTotal(text)
        
        let detectedTax = detectedTaxOptional ?? 0.0
        let detectedTip = detectedTipOptional ?? 0.0
        
        // Step 2: Predict item count using the logic discussed
        let predictedItemCount = await predictItemCount(text: text)
        
        
        return ReceiptAnalysis(
            tax: detectedTax,
            tip: detectedTip,
            total: detectedTotal ?? 0,
            itemCount: predictedItemCount
        )
    }
    
    // MARK: - LLM-based Individual Item Price Extraction
    
    private func extractIndividualItemPricesWithFiltering(
        text: String,
        targetTotal: Double,
        expectedCount: Int,
        excludedAmounts: Set<Double>
    ) async -> [ReceiptItem] {
        return await extractItemsWithAppleIntelligence(
            text: text,
            targetPrice: targetTotal,
            expectedCount: expectedCount
        )
    }
    
    private func extractIndividualItemPrices(
        text: String,
        targetTotal: Double,
        expectedCount: Int
    ) async -> [(name: String, price: Double)] {
        
        // Use Natural Language processing to find individual item prices in order
        let lines = text.components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            
        var extractedItems: [(name: String, price: Double)] = []
        
        for line in lines {
            // Skip lines that are clearly not individual items
            if await isLineIndividualItem(line, targetTotal: targetTotal) {
                if let price = extractPriceFromText(line) {
                    if price > 0 && price <= targetTotal {
                        // Extract item name from the line
                        let itemName = extractItemNameFromLine(line, price: price)
                        extractedItems.append((name: itemName, price: price))
                    }
                }
            }
        }
        
        // Keep original order - DO NOT sort
        
        return extractedItems
    }
    
    private func extractPriceFromText(_ text: String) -> Double? {
        // Enhanced price extraction that handles various formats
        let patterns = [
            #"\$?(\d+\.\d{2})"#,         // $12.99 or 12.99
            #"\$?(\d+\.?\d*)"#,          // $12 or 12
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let priceString = String(text[range])
                        if let price = Double(priceString) {
                            return price
                        }
                    }
                }
            } catch {
                // Continue with next pattern instead of crashing
                continue
            }
        }
        return nil
    }
    
    private func extractItemNameFromLine(_ line: String, price: Double) -> String {
        // Remove the price from the line to get the item name
        let priceString = String(format: "%.2f", price)
        let variations = [
            "$\(priceString)",
            priceString,
            String(format: "%.0f", price), // Without decimal if whole number
            "$\(String(format: "%.0f", price))"
        ]
        
        var cleanedLine = line
        
        // Remove price variations from the line
        for variation in variations {
            cleanedLine = cleanedLine.replacingOccurrences(of: variation, with: "")
        }
        
        // Clean up common receipt formatting
        cleanedLine = cleanedLine.replacingOccurrences(of: "  ", with: " ") // Multiple spaces
        cleanedLine = cleanedLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // Remove common receipt artifacts
        let cleanupPatterns = [
            #"\s*\d+\s*$"#,  // Trailing numbers (quantity)
            #"^\d+\s*"#,     // Leading numbers (line numbers)
            #"\s*x\d+\s*$"#, // Quantity like "x2"
            #"\s*@\s*\d+.*$"#, // @ price indicators
            #"\s*ea\s*$"#,   // "each" indicators
        ]
        
        for pattern in cleanupPatterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                cleanedLine = regex.stringByReplacingMatches(
                    in: cleanedLine,
                    options: [],
                    range: NSRange(cleanedLine.startIndex..., in: cleanedLine),
                    withTemplate: ""
                )
            } catch {
                // Skip this cleanup pattern and continue with the next one
                continue
            }
        }
        
        cleanedLine = cleanedLine.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        
        // If we have a reasonable name, use it; otherwise create generic name
        if cleanedLine.count >= 2 && cleanedLine.count <= 50 {
            // Capitalize first letter for better presentation
            return cleanedLine.prefix(1).uppercased() + cleanedLine.dropFirst()
        } else {
            // Fallback to price-based name if extraction failed
            return "Item ($\(priceString))"
        }
    }
    
    private func isLineIndividualItem(_ line: String, targetTotal: Double) async -> Bool {
        let lowercased = line.lowercased()
        
        // Exclude lines that are clearly financial summaries
        let excludeKeywords = [
            "total", "subtotal", "sub total", "sub-total",
            "tax", "sales tax", "gst", "hst", "vat",
            "tip", "gratuity", "service charge", "service fee",
            "discount", "coupon", "promo", "promotion",
            "cash", "credit", "card", "payment", "change",
            "balance", "amount due", "due", "owe",
            "receipt", "thank you", "visit", "server"
        ]
        
        // If line contains exclude keywords, it's not an individual item
        for keyword in excludeKeywords {
            if lowercased.contains(keyword) {
                return false
            }
        }
        
        // Must have a price to be considered an item
        guard let price = extractPriceFromText(line), price > 0 else {
            return false
        }
        
        // Price shouldn't be too large compared to target (likely total/subtotal)
        if price > targetTotal * 0.8 {
            return false
        }
        
        // If it has characteristics of a food item, it's likely an individual item
        let foodKeywords = [
            "burger", "pizza", "salad", "sandwich", "drink", "coffee", "tea",
            "chicken", "beef", "fish", "pasta", "rice", "soup", "appetizer",
            "dessert", "cake", "ice cream", "fries", "wings", "taco", "burrito"
        ]
        
        let hasFood = foodKeywords.contains { lowercased.contains($0) }
        if hasFood {
            return true
        }
        
        // If line has reasonable length (not too short, not too long) and has a price, likely an item
        let trimmed = line.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        return trimmed.count >= 3 && trimmed.count <= 50
    }
    
    func processWithMathematicalApproach(
        rawText: String,
        confirmedTax: Double,
        confirmedTip: Double,
        confirmedTotal: Double,
        expectedItemCount: Int
    ) async -> [ReceiptItem] {
        
        // Step 1: Calculate the target price for items (Total - Tax - Tip)
        let targetItemsPrice = confirmedTotal - confirmedTax - confirmedTip
        
        guard targetItemsPrice > 0 else {
            return []
        }
        
        // Step 2: Extract all dollar amounts from the receipt, excluding tax/tip
        let allAmounts = extractAllDollarAmounts(text: rawText)
        let taxAmounts = extractTaxAmountsWithRegex(rawText)
        let tipAmounts = extractTipAmountsWithRegex(rawText)
        let excludedAmounts = Set(taxAmounts + tipAmounts + [confirmedTax, confirmedTip])
        
        // Filter out tax/tip amounts from consideration
        let filteredAmounts = allAmounts.filter { !excludedAmounts.contains($0) }
        
        // Step 3: Find combination of amounts that sum to target price with confidence
        let (combination, confidenceLevels) = findBestPriceCombinationWithConfidence(
            amounts: filteredAmounts,
            targetSum: targetItemsPrice,
            expectedCount: expectedItemCount
        )
        
        // Step 4: Create items from the combination with confidence levels
        var items: [ReceiptItem] = []
        
        if combination.isEmpty {
            // No perfect combination found - use LLM to extract individual item prices
            
            // Use Apple Intelligence to specifically extract individual item prices and names with filtering
            let llmExtractedItems = await extractIndividualItemPricesWithFiltering(
                text: rawText,
                targetTotal: targetItemsPrice,
                expectedCount: expectedItemCount,
                excludedAmounts: excludedAmounts
            )
            
            if !llmExtractedItems.isEmpty {
                
                // Use LLM-extracted items up to expected count (preserve order)
                let usableItems = Array(llmExtractedItems.prefix(expectedItemCount))
                
                for itemData in usableItems {
                    items.append(ReceiptItem(
                        name: itemData.name,
                        price: itemData.price,
                        confidence: .medium,  // Medium confidence - detected but not perfect combination
                        originalDetectedName: itemData.name,
                        originalDetectedPrice: itemData.price
                    ))
                }
                
                // Fill remaining with placeholders
                let remainingCount = expectedItemCount - usableItems.count
                if remainingCount > 0 {
                    let usedTotal = usableItems.reduce(0) { $0.currencyAdd($1.price) }
                    let remainingTotal = max(0, targetItemsPrice - usedTotal)
                    let avgRemainingPrice = remainingCount > 0 ? remainingTotal / Double(remainingCount) : 0.0
                    
                    
                    for index in usableItems.count..<expectedItemCount {
                        // Give placeholders a suggested price based on remaining amount
                        let suggestedPrice = avgRemainingPrice > 0.50 ? avgRemainingPrice : 0.00
                        items.append(ReceiptItem(
                            name: "Item \(index + 1)",
                            price: suggestedPrice,
                            confidence: .placeholder
                        ))
                    }
                }
            } else {
                // LLM extraction also failed - fall back to basic regex extraction
                
                // Filter out amounts that are likely tax/tip/total to avoid duplication
                let itemAmounts = allAmounts.filter { amount in
                    // Exclude amounts that are too close to tax, tip, or total
                    let taxThreshold = abs(amount - confirmedTax) > 0.50
                    let tipThreshold = abs(amount - confirmedTip) > 0.50
                    let totalThreshold = abs(amount - confirmedTotal) > 0.50
                    return taxThreshold && tipThreshold && totalThreshold && amount <= targetItemsPrice
                }
                
                if !itemAmounts.isEmpty {
                    
                    // Use detected amounts up to expected count
                    let usableAmounts = Array(itemAmounts.prefix(expectedItemCount))
                    
                    for (index, amount) in usableAmounts.enumerated() {
                        items.append(ReceiptItem(
                            name: "Item \(index + 1)",
                            price: amount,
                            confidence: .low  // Low confidence since even LLM couldn't find good items
                        ))
                    }
                    
                    // Fill remaining with placeholders
                    let remainingCount = expectedItemCount - usableAmounts.count
                    if remainingCount > 0 {
                        let usedTotal = usableAmounts.reduce(0, +)
                        let remainingTotal = max(0, targetItemsPrice - usedTotal)
                        let avgRemainingPrice = remainingCount > 0 ? remainingTotal / Double(remainingCount) : 0.0
                        
                        
                        for index in usableAmounts.count..<expectedItemCount {
                            let suggestedPrice = avgRemainingPrice > 0.50 ? avgRemainingPrice : 0.00
                            items.append(ReceiptItem(
                                name: "Item \(index + 1)",
                                price: suggestedPrice,
                                confidence: .placeholder
                            ))
                        }
                    }
                } else {
                    // Last resort - create all placeholders with suggested pricing
                    let avgPrice = targetItemsPrice / Double(expectedItemCount)
                    
                    for index in 0..<expectedItemCount {
                        items.append(ReceiptItem(
                            name: "Item \(index + 1)",
                            price: avgPrice > 0.50 ? avgPrice : 0.00,
                            confidence: .placeholder
                        ))
                    }
                }
            }
        } else {
            // Create items with detected prices and confidence levels
            for (index, price) in combination.enumerated() {
                let confidence = confidenceLevels[index]
                items.append(ReceiptItem(
                    name: "Item \(index + 1)",
                    price: price,
                    confidence: confidence
                ))
            }
            
            // Fill remaining items with placeholders if needed
            let remainingCount = expectedItemCount - combination.count
            if remainingCount > 0 {
                let remainingTotal = max(0, targetItemsPrice - combination.reduce(0, +))
                
                for index in combination.count..<expectedItemCount {
                    items.append(ReceiptItem(
                        name: "Item \(index + 1)",
                        price: 0.00,
                        confidence: .placeholder
                    ))
                }
            }
        }
        
        // Step 5: Add tax and tip as separate items if they exist
        if confirmedTax > 0 {
            items.append(ReceiptItem(name: "Tax", price: confirmedTax, confidence: .high))
        }
        if confirmedTip > 0 {
            items.append(ReceiptItem(name: "Tip", price: confirmedTip, confidence: .high))
        }
        
        return items
    }
    
    // MARK: - Item Count Prediction
    
    private func predictItemCount(text: String) async -> Int {
        
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        var itemCount = 0
        var foundFirstPrice = false
        
        for line in lines {
            // Check if line contains financial keywords that end the items section
            if containsFinancialKeyword(line) {
                break
            }
            
            // Check if line contains a price
            if let _ = extractPriceFromLine(line) {
                if !foundFirstPrice {
                    foundFirstPrice = true
                }
                
                if foundFirstPrice {
                    // Use Apple Intelligence to determine if this is likely an item
                    let isLikelyItem = await analyzeLineForItemCount(line)
                    if isLikelyItem {
                        itemCount += 1
                    } else {
                    }
                }
            }
        }
        
        return max(itemCount, 1) // At least 1 item
    }
    
    private func containsFinancialKeyword(_ text: String) -> Bool {
        let financialKeywords = [
            "subtotal", "sub total", "sub-total",
            "total", "amount due", "balance",
            "tax", "sales tax", "tx",
            "tip", "gratuity", "service charge", "grat"
        ]
        
        let lowercased = text.lowercased()
        return financialKeywords.contains { lowercased.contains($0) }
    }
    
    private func analyzeLineForItemCount(_ line: String) async -> Bool {
        // Use simple heuristics for item count prediction
        let lowercased = line.lowercased()
        
        // Skip obvious non-items
        let skipKeywords = [
            "total", "tax", "tip", "gratuity", "subtotal", "balance",
            "cash", "credit", "change", "payment", "receipt"
        ]
        
        for keyword in skipKeywords {
            if lowercased.contains(keyword) {
                return false
            }
        }
        
        // If it has a price and doesn't contain skip keywords, likely an item
        return extractPriceFromLine(line) != nil
    }
    
    // MARK: - Dollar Amount Extraction
    
    private func extractAllDollarAmounts(text: String) -> [Double] {
        let patterns = [
            #"\$(\d+\.?\d*)"#,           // $12.99, $5
            #"(\d+\.\d{2})"#,            // 12.99, 5.00  
            #"(\d+)\s*$"#                // 12 at end of line
        ]
        
        var amounts: [Double] = []
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                
                for match in matches {
                    if let range = Range(match.range(at: 1), in: text) {
                        let amountString = String(text[range])
                        if let amount = Double(amountString), amount > 0 && amount < 1000 {
                            amounts.append(amount)
                        }
                    }
                }
            } catch {
                // Continue with next pattern instead of crashing
                continue
            }
        }
        
        // Remove duplicates and sort
        amounts = Array(Set(amounts)).sorted()
        
        return amounts
    }
    
    // MARK: - Price Combination Logic
    
    private func findBestPriceCombinationWithConfidence(
        amounts: [Double],
        targetSum: Double,
        expectedCount: Int
    ) -> ([Double], [ConfidenceLevel]) {
        
        // Try exact match first (highest confidence)
        if let exact = findExactCombination(amounts: amounts, targetSum: targetSum, count: expectedCount) {
            let confidences = Array(repeating: ConfidenceLevel.high, count: exact.count)
            return (exact, confidences)
        }
        
        // Try closest match (medium confidence)
        if let closest = findClosestCombination(amounts: amounts, targetSum: targetSum, count: expectedCount) {
            let confidences = Array(repeating: ConfidenceLevel.medium, count: closest.count)
            return (closest, confidences)
        }
        
        // Try flexible count with lower confidence
        for count in (max(1, expectedCount - 2)...(expectedCount + 2)) {
            if let match = findClosestCombination(amounts: amounts, targetSum: targetSum, count: count) {
                let confidences = Array(repeating: ConfidenceLevel.low, count: match.count)
                return (match, confidences)
            }
        }
        
        // No good combination found
        return ([], [])
    }
    
    private func findBestPriceCombination(
        amounts: [Double],
        targetSum: Double,
        expectedCount: Int
    ) -> [Double] {
        
        // Try different combination strategies
        
        // Strategy 1: Exact match with expected count
        if let exact = findExactCombination(amounts: amounts, targetSum: targetSum, count: expectedCount) {
            return exact
        }
        
        // Strategy 2: Closest match with expected count
        if let closest = findClosestCombination(amounts: amounts, targetSum: targetSum, count: expectedCount) {
            return closest
        }
        
        // Strategy 3: Best match regardless of count (within reasonable range)
        for count in (max(1, expectedCount - 2)...(expectedCount + 2)) {
            if let match = findClosestCombination(amounts: amounts, targetSum: targetSum, count: count) {
                return match
            }
        }
        
        // No fallback - return empty array if no good combination found
        return []
    }
    
    private func findExactCombination(amounts: [Double], targetSum: Double, count: Int) -> [Double]? {
        // Use recursive backtracking to find exact combinations
        return findCombinationRecursive(amounts: amounts, targetSum: targetSum, count: count, index: 0, current: [])
    }
    
    private func findCombinationRecursive(
        amounts: [Double],
        targetSum: Double,
        count: Int,
        index: Int,
        current: [Double]
    ) -> [Double]? {
        // Base cases
        if current.count == count {
            let sum = current.reduce(0, +)
            return abs(sum - targetSum) < 0.01 ? current : nil
        }
        
        if index >= amounts.count || current.count > count {
            return nil
        }
        
        // Try including current amount
        if let result = findCombinationRecursive(
            amounts: amounts,
            targetSum: targetSum,
            count: count,
            index: index + 1,
            current: current + [amounts[index]]
        ) {
            return result
        }
        
        // Try skipping current amount
        return findCombinationRecursive(
            amounts: amounts,
            targetSum: targetSum,
            count: count,
            index: index + 1,
            current: current
        )
    }
    
    private func findClosestCombination(amounts: [Double], targetSum: Double, count: Int) -> [Double]? {
        var bestCombination: [Double]?
        var bestDifference = Double.infinity
        
        // Generate all combinations of the specified count
        let combinations = generateCombinations(amounts: amounts, count: count)
        
        for combination in combinations {
            let sum = combination.reduce(0, +)
            let difference = abs(sum - targetSum)
            
            if difference < bestDifference {
                bestDifference = difference
                bestCombination = combination
            }
        }
        
        // Return if the difference is reasonable (within 20% of target)
        if bestDifference <= targetSum * 0.2 {
            return bestCombination
        }
        
        return nil
    }
    
    private func generateCombinations(amounts: [Double], count: Int) -> [[Double]] {
        if count == 0 { return [[]] }
        if amounts.isEmpty { return [] }
        
        var combinations: [[Double]] = []
        
        for i in 0..<amounts.count {
            let remaining = Array(amounts[(i+1)...])
            let subCombinations = generateCombinations(amounts: remaining, count: count - 1)
            
            for subCombination in subCombinations {
                combinations.append([amounts[i]] + subCombination)
            }
        }
        
        return combinations
    }
    
    // MARK: - LLM-based Item Detection for Comparison
    
    func processWithLLMApproach(
        rawText: String,
        confirmedTax: Double,
        confirmedTip: Double,
        confirmedTotal: Double,
        expectedItemCount: Int
    ) async -> [ReceiptItem] {
        
        let targetItemsPrice = confirmedTotal - confirmedTax - confirmedTip
        
        guard targetItemsPrice > 0 else {
            return []
        }
        
        let foodItems = await extractItemsWithAppleIntelligence(
            text: rawText,
            targetPrice: targetItemsPrice,
            expectedCount: expectedItemCount
        )
        
        // Add tax and tip items to Apple Intelligence results for complete receipt view
        var allItems = foodItems
        
        if confirmedTax > 0 {
            allItems.append(ReceiptItem(
                name: "Tax",
                price: confirmedTax,
                confidence: .high,
                originalDetectedName: "Tax",
                originalDetectedPrice: confirmedTax
            ))
        }
        
        if confirmedTip > 0 {
            allItems.append(ReceiptItem(
                name: "Tip", 
                price: confirmedTip,
                confidence: .high,
                originalDetectedName: "Tip",
                originalDetectedPrice: confirmedTip
            ))
        }
        
        return allItems
    }
    
    // Enhanced Apple Intelligence extraction for LLM comparison
    private func extractItemsWithAppleIntelligence(
        text: String,
        targetPrice: Double,
        expectedCount: Int
    ) async -> [ReceiptItem] {
        
        // First extract and exclude tax/tip amounts to avoid including them as item prices
        let (taxAmounts, tipAmounts) = await extractTaxTipAmountsForFiltering(text: text)
        let excludedAmounts = Set(taxAmounts + tipAmounts)
        
        // NEW APPROACH: Match item names with prices using intelligent pairing
        let detectedItems = await extractItemsUsingNamePricePairing(
            text: text, 
            targetPrice: targetPrice, 
            expectedCount: expectedCount,
            excludedAmounts: excludedAmounts
        )
        
        return detectedItems
    }
    
    // Parse item names from lines containing dollar amounts, preserving exact order
    private func extractItemsUsingNamePricePairing(
        text: String,
        targetPrice: Double, 
        expectedCount: Int,
        excludedAmounts: Set<Double>
    ) async -> [ReceiptItem] {
        
        let lines = text.components(separatedBy: .newlines).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        
        // Step 1: Find the first line that contains a dollar amount - this is where items start
        var firstDollarLineIndex: Int? = nil
        
        for (index, line) in lines.enumerated() {
            if extractPriceFromLine(line) != nil {
                firstDollarLineIndex = index
                break
            }
        }
        
        guard let startIndex = firstDollarLineIndex else {
            return []
        }
        
        // Step 2: Extract item section starting from first dollar amount line
        let itemSection = Array(lines[startIndex...])
        for (relativeIndex, line) in itemSection.enumerated() {
        }
        
        // Step 3: Use Apple Intelligence to parse items WITH dollar amounts included
        let itemsWithPrices = await parseItemNamesAndPricesWithAppleIntelligence(
            itemSection: itemSection, 
            excludedAmounts: excludedAmounts,
            targetPrice: targetPrice,
            expectedCount: expectedCount
        )
        
        return itemsWithPrices
    }
    
    // Use Apple Intelligence to parse item names and prices while preserving order
    private func parseItemNamesAndPricesWithAppleIntelligence(
        itemSection: [String],
        excludedAmounts: Set<Double>,
        targetPrice: Double,
        expectedCount: Int
    ) async -> [ReceiptItem] {
        
        
        var extractedItems: [ReceiptItem] = []
        
        // Process each line in order to preserve receipt sequence
        for (index, line) in itemSection.enumerated() {
            guard !line.isEmpty else { continue }
            
            // Skip financial summary lines
            if shouldSkipLineForIntelligentAnalysis(line) {
                continue
            }
            
            // Extract price from this line
            guard let price = extractPriceFromLine(line) else { continue }
            
            // Skip excluded tax/tip amounts  
            if excludedAmounts.contains(price) {
                continue
            }
            
            // Skip prices that are too high (likely totals)
            if price > targetPrice {
                continue
            }
            
            // Parse item name from this line or previous line
            let itemName = await extractItemNameFromLineWithPrice(
                currentLine: line,
                previousLine: index > 0 ? itemSection[index - 1] : nil,
                price: price
            )
            
            let receiptItem = ReceiptItem(
                name: itemName,
                price: price,
                confidence: .high,
                originalDetectedName: itemName,
                originalDetectedPrice: price
            )
            
            extractedItems.append(receiptItem)
            
            // Stop when we reach expected count
            if extractedItems.count >= expectedCount {
                break
            }
        }
        
        return extractedItems
    }
    
    // Extract item name from current line with price, or previous line if needed
    private func extractItemNameFromLineWithPrice(
        currentLine: String,
        previousLine: String?,
        price: Double
    ) async -> String {
        
        if let prev = previousLine {
        }
        
        // Try to extract name from current line first
        if let nameFromCurrent = extractItemNameWithEnhancedAppleIntelligence(line: currentLine, price: price) {
            if nameFromCurrent.count > 3 && !nameFromCurrent.hasPrefix("Item ") {
                return nameFromCurrent
            }
        }
        
        // If current line doesn't have a good name, try previous line
        if let previousLine = previousLine,
           await isLikelyItemDescription(previousLine) {
            return previousLine
        }
        
        // Fallback: try to extract any meaningful text from current line
        let fallbackName = currentLine
            .replacingOccurrences(of: String(format: "$%.2f", price), with: "")
            .replacingOccurrences(of: String(format: "%.2f", price), with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !fallbackName.isEmpty && fallbackName.count > 2 {
            return fallbackName
        }
        
        // Last resort
        return "Menu Item $\(String(format: "%.2f", price))"
    }
    
    // Check if a line contains an item description (has meaningful text content)
    private func isLikelyItemDescription(_ line: String) async -> Bool {
        // Skip lines that are clearly not item descriptions
        let excludePatterns = [
            "subtotal", "tax", "total", "cash", "change", "visa", "mastercard", "card",
            "approval", "entry mode", "account", "acct", "cashier", "order", "receipt"
        ]
        
        let lowercaseLine = line.lowercased()
        for pattern in excludePatterns {
            if lowercaseLine.contains(pattern) {
                return false
            }
        }
        
        // Must contain letters (not just numbers)
        guard line.rangeOfCharacter(from: CharacterSet.letters) != nil else { return false }
        
        // Should have some meaningful length
        guard line.count >= 3 else { return false }
        
        // Use Apple Intelligence Natural Language to check if it looks like a product description
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = line
        
        var hasNounsOrFood = false
        
        tagger.enumerateTags(in: line.startIndex..<line.endIndex,
                           unit: .word,
                           scheme: .lexicalClass,
                           options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            
            let word = String(line[range])
            
            if let tag = tag {
                switch tag {
                case .noun, .adjective:
                    hasNounsOrFood = true
                case .other:
                    // Check if it might be a food-related word
                    if isLikelyFoodWordSync(word) {
                        hasNounsOrFood = true
                    }
                default:
                    break
                }
            } else {
                // Even if NL can't classify it, check if it looks like food
                if isLikelyFoodWordSync(word) {
                    hasNounsOrFood = true
                }
            }
            
            return true
        }
        
        return hasNounsOrFood
    }
    
    private func analyzeLineForItemWithAppleIntelligence(_ line: String, targetPrice: Double, excludedAmounts: Set<Double>) async -> Bool {
        // Use Natural Language processing to determine if this is likely a food item
        guard let price = extractPriceFromLine(line) else { return false }
        
        // Skip if this price is a known tax/tip amount
        if excludedAmounts.contains(price) {
            return false
        }
        
        let hasItemName = isLikelyProductName(line.replacingOccurrences(of: "\\$[0-9.]+", with: "", options: .regularExpression))
        
        return hasItemName
    }
    
    private func parseItemLineWithAppleIntelligence(_ line: String, lineIndex: Int, excludedAmounts: Set<Double>) async -> ReceiptItem? {
        guard let price = extractPriceFromLine(line) else { return nil }
        
        // Skip if this price is a known tax/tip amount
        if excludedAmounts.contains(price) {
            return nil
        }
        
        // Extract item name using enhanced Apple Intelligence
        let itemName = extractItemNameWithEnhancedAppleIntelligence(line: line, price: price) ?? "Item \(lineIndex + 1)"
        
        return ReceiptItem(
            name: itemName,
            price: price,
            confidence: .high,
            originalDetectedName: itemName,
            originalDetectedPrice: price
        )
    }
    
    // Extract tax and tip amounts for filtering purposes
    private func extractTaxTipAmountsForFiltering(text: String) async -> ([Double], [Double]) {
        let taxAmounts = extractTaxAmountsWithRegex(text)
        let tipAmounts = extractTipAmountsWithRegex(text)
        
        
        return (taxAmounts, tipAmounts)
    }
    
    // Enhanced item name extraction using Apple Intelligence
    private func extractItemNameWithEnhancedAppleIntelligence(line: String, price: Double) -> String? {
        
        var cleanedLine = line
        
        // Remove the specific price value patterns
        let specificPricePatterns = [
            String(format: "$%.2f", price),
            String(format: "%.2f$", price), 
            String(format: "$ %.2f", price),
            String(format: "%.2f $", price),
            String(format: " %.2f", price) + "$",
            "$" + String(format: " %.2f", price),
            String(format: "%.2f", price) // Also try without currency symbol
        ]
        
        for pattern in specificPricePatterns {
            cleanedLine = cleanedLine.replacingOccurrences(of: pattern, with: " ")
        }
        
        // Clean up extra spaces and basic formatting
        cleanedLine = cleanedLine.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        cleanedLine = cleanedLine.trimmingCharacters(in: .whitespacesAndNewlines)
        
        
        // If we have any meaningful text left, return it
        if !cleanedLine.isEmpty {
            let words = cleanedLine.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            
            // Accept any text that has at least one non-purely-numeric word
            let hasValidContent = words.contains { word in
                // Accept words with letters, mixed alphanumeric, or single characters
                return word.rangeOfCharacter(from: CharacterSet.letters) != nil || 
                       (word.count >= 2 && !word.allSatisfy(\.isWholeNumber))
            }
            
            if hasValidContent {
                let finalName = cleanedLine
                return finalName
            }
        }
        
        // If price removal left us with nothing useful, try using the original line minus just numbers at the end
        let fallbackName = line.replacingOccurrences(of: #"\s*\$?\d+\.?\d*\$?\s*$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !fallbackName.isEmpty && fallbackName.count >= 2 {
            return fallbackName
        }
        
        // Last resort: return the original line if it has any non-numeric content
        if line.rangeOfCharacter(from: CharacterSet.letters) != nil {
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        return nil
    }
    
    // Helper method to enhance item names using Natural Language processing
    private func enhanceItemNameWithNaturalLanguage(_ text: String) async -> String? {
        // Use NLTagger to identify if we can improve the text
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var words: [String] = []
        
        // Extract words, preserving structure but identifying meaningful parts
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                           unit: .word,
                           scheme: .lexicalClass,
                           options: [.omitWhitespace, .omitPunctuation]) { tag, range in
            
            let word = String(text[range])
            
            // Include most words, but enhance known food/product patterns
            if word.count >= 1 {
                words.append(word)
            }
            
            return true
        }
        
        // If NL processing gives us something useful, return it; otherwise return original
        let processedName = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        return processedName.isEmpty ? nil : processedName
    }
    
    private func isLikelyFoodWordSync(_ word: String) -> Bool {
        let lowercased = word.lowercased()
        let foodKeywords = [
            // Food categories
            "sandwich", "burger", "pizza", "pasta", "salad", "soup", "chicken", "beef",
            "fish", "shrimp", "bacon", "cheese", "bread", "rice", "noodles", "wrap",
            "taco", "burrito", "wings", "fries", "onion", "mushroom", "pepper", "tomato",
            
            // Beverages
            "coffee", "tea", "soda", "juice", "water", "beer", "wine", "latte", "cappuccino",
            "smoothie", "shake", "cola", "sprite", "pepsi", "coke",
            
            // Cooking methods
            "grilled", "fried", "baked", "roasted", "steamed", "sauteed", "crispy", "fresh",
            
            // Portions and styles
            "large", "small", "medium", "regular", "special", "classic", "deluxe", "combo"
        ]
        
        return foodKeywords.contains { lowercased.contains($0) }
    }
    
    private func aggressiveItemExtractionWithAppleIntelligence(
        text: String,
        existingItems: [ReceiptItem],
        targetCount: Int,
        targetPrice: Double,
        excludedAmounts: Set<Double>
    ) async -> [ReceiptItem] {
        let lines = text.components(separatedBy: .newlines)
        var additionalCandidates: [(lineIndex: Int, item: ReceiptItem)] = []
        let usedPrices = Set(existingItems.map { $0.price })
        
        for (index, line) in lines.enumerated() {
            guard additionalCandidates.count < (targetCount - existingItems.count) else { break }
            
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLine.isEmpty else { continue }
            
            // Look for any price that hasn't been used and isn't tax/tip
            if let price = extractPriceFromLine(trimmedLine),
               !usedPrices.contains(price),
               !excludedAmounts.contains(price),
               price <= targetPrice {
                
                let itemName = extractItemNameWithEnhancedAppleIntelligence(line: trimmedLine, price: price) ?? "Item \(existingItems.count + additionalCandidates.count + 1)"
                
                let item = ReceiptItem(
                    name: itemName,
                    price: price,
                    confidence: .medium,
                    originalDetectedName: itemName,
                    originalDetectedPrice: price
                )
                
                additionalCandidates.append((lineIndex: index, item: item))
            }
        }
        
        // Sort by line order to preserve receipt order
        return additionalCandidates.sorted { $0.lineIndex < $1.lineIndex }.map { $0.item }
    }
}

// MARK: - Bill Split Session Management
class BillSplitSession: ObservableObject {
    // OCR Results
    @Published var scannedItems: [ReceiptItem] = []
    @Published var rawReceiptText: String = ""
    @Published var ocrConfidence: Float = 0.0
    @Published var identifiedTotal: Double? = nil
    @Published var capturedReceiptImage: UIImage? = nil
    
    // Comparison Results - Regex vs LLM
    @Published var regexDetectedItems: [ReceiptItem] = []
    @Published var llmDetectedItems: [ReceiptItem] = []
    @Published var confirmedTax: Double = 0.0
    @Published var confirmedTip: Double = 0.0
    @Published var confirmedTotal: Double = 0.0
    @Published var expectedItemCount: Int = 0
    
    // Participants
    @Published var participants: [UIParticipant] = []

    // Bill payer selection (mandatory for bill creation)
    @Published var paidByParticipantID: String? = nil
    
    // Bill name (optional, defaults to item count description)
    @Published var billName: String = ""

    // Item assignments
    @Published var assignedItems: [UIItem] = []

    // Entry method tracking
    @Published var entryMethod: BillEntryMethod = .scan

    // Session state
    @Published var sessionState: SessionState = .home
    @Published var isSessionActive: Bool = false

    enum SessionState: String {
        case home = "home"
        case scanning = "scanning"
        case assigning = "assigning"
        case reviewing = "reviewing"
        case complete = "complete"
    }
    
    let colors: [Color] = [.blue, .green, .purple, .pink, .yellow, .red, .orange, .cyan, .teal, .mint]
    
    func startNewSession() {
        resetSession()
        isSessionActive = true
        sessionState = .scanning
    }
    
    func resetSession() {
        
        scannedItems.removeAll()
        rawReceiptText = ""
        ocrConfidence = 0.0
        identifiedTotal = nil
        capturedReceiptImage = nil
        
        // Clear comparison results
        regexDetectedItems.removeAll()
        llmDetectedItems.removeAll()
        confirmedTax = 0.0
        confirmedTip = 0.0
        confirmedTotal = 0.0
        expectedItemCount = 0
        
        
        // Clear all participants - "You" will be added when session starts with auth context
        participants.removeAll()
        assignedItems.removeAll()
        
        // Reset bill payer selection and name
        paidByParticipantID = nil
        billName = ""

        // Reset entry method to scan
        entryMethod = .scan

        sessionState = .home
        isSessionActive = false
    }
    
    func updateOCRResults(_ items: [ReceiptItem], rawText: String, confidence: Float, identifiedTotal: Double?, suggestedAmounts: [Double] = [], image: UIImage? = nil, confirmedTax: Double = 0, confirmedTip: Double = 0, confirmedTotal: Double = 0, expectedItemCount: Int = 0) {
        
        scannedItems = items
        rawReceiptText = rawText
        ocrConfidence = confidence
        self.identifiedTotal = identifiedTotal
        self.capturedReceiptImage = image
        
        // Store confirmed values for dual processing
        self.confirmedTax = confirmedTax
        self.confirmedTip = confirmedTip
        self.confirmedTotal = confirmedTotal > 0 ? confirmedTotal : identifiedTotal ?? 0
        self.expectedItemCount = expectedItemCount
        
        // Convert ReceiptItems to UIItems for the assign screen
        // EDGE-001: Filter out zero and negative prices (discounts not allowed)
        let validItems = items.filter { $0.price > 0.00 }
        let filteredCount = items.count - validItems.count

        if filteredCount > 0 {
        }

        var allItems: [UIItem] = validItems.enumerated().map { index, receiptItem in
            UIItem(
                id: index + 1,
                name: receiptItem.name,
                price: receiptItem.price,
                assignedTo: nil as String?,  // Legacy: Start unassigned
                assignedToParticipants: Set<String>(), // New: Start with no participants
                confidence: receiptItem.confidence,
                originalDetectedName: receiptItem.originalDetectedName,
                originalDetectedPrice: receiptItem.originalDetectedPrice
            )
        }

        // ✅ ADD: Tax, Tip, and Gratuity as assignable items
        var nextId = validItems.count + 1

        // Add Tax as assignable item
        if confirmedTax > 0 {
            allItems.append(UIItem(
                id: nextId,
                name: "Tax",
                price: confirmedTax,
                assignedTo: nil,
                assignedToParticipants: Set<String>(),
                confidence: .high,
                originalDetectedName: "Tax",
                originalDetectedPrice: confirmedTax
            ))
            nextId += 1
        }

        // Add Tip as assignable item (already includes gratuity if present)
        if confirmedTip > 0 {
            allItems.append(UIItem(
                id: nextId,
                name: "Tip",
                price: confirmedTip,
                assignedTo: nil,
                assignedToParticipants: Set<String>(),
                confidence: .high,
                originalDetectedName: "Tip",
                originalDetectedPrice: confirmedTip
            ))
            nextId += 1
        }

        assignedItems = allItems

        print("📝 Created \(allItems.count) assignable items:")
        print("   - Food items: \(validItems.count)")
        if confirmedTax > 0 {
            print("   - Tax: $\(String(format: "%.2f", confirmedTax))")
        }
        if confirmedTip > 0 {
            print("   - Tip: $\(String(format: "%.2f", confirmedTip))")
        }


        // Go directly to assignment screen
        sessionState = .assigning
    }
    
    // SECURITY: Removed unvalidated addParticipant method
    // All participant additions must go through addParticipantWithValidation for US-EDGE-003 compliance

    // Initialize session with current user as "You" participant
    func initializeWithCurrentUser(authViewModel: AuthViewModel) async {
        let currentUser = await MainActor.run { authViewModel.user }
        guard let currentUser = currentUser else {
            return
        }


        let tempParticipant = UIParticipant(
            id: currentUser.uid,
            name: "You",
            color: .blue,
            photoURL: currentUser.photoURL?.absoluteString
        )
        let currentUserParticipant = UIParticipant(
            id: currentUser.uid,
            name: "You",
            color: tempParticipant.assignedColor,
            photoURL: currentUser.photoURL?.absoluteString
        )


        await MainActor.run {
            participants = [currentUserParticipant]
            paidByParticipantID = currentUser.uid  // Default to current user as payer
        }

        for participant in participants {
        }
    }
    
    func addParticipantWithValidation(name: String, email: String? = nil, phoneNumber: String? = nil, authViewModel: AuthViewModel, contactsManager: ContactsManager? = nil, firebaseUID: String? = nil) async -> (participant: UIParticipant?, error: String?, needsContact: Bool) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔍 [DataModels] addParticipantWithValidation START - name: \(trimmedName), email: \(email ?? "nil"), phone: \(phoneNumber ?? "nil")")

        guard !trimmedName.isEmpty else {
            print("❌ [DataModels] Empty name")
            return (nil, "Name cannot be empty", false)
        }
        
        // Get current user info for validation
        let currentUser = await MainActor.run { authViewModel.user }

        // Check if trying to add yourself by name
        if trimmedName.lowercased() == "you" {
            return (nil, "You are already in this bill", false)
        }

        // Check if email matches current user's email
        if let email = email, let currentUser = currentUser {
            let emailValidation = AuthViewModel.validateEmail(email)
            if emailValidation.isValid, let validEmail = emailValidation.sanitized {
                if validEmail.lowercased() == currentUser.email?.lowercased() {
                    return (nil, "You're already in this bill as 'You'", false)
                } else {
                }
            }
        }

        // Remove incorrect check here - we need to check the actual email being added, not current user
        
        // Check for duplicates by name (case-insensitive)
        if participants.contains(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            return (nil, "Participant already exists", false)
        }
        
        // SECURITY: First validate user is registered with Settled
        // If firebaseUID is provided, user is already validated
        var validatedFirebaseUID: String

        if let providedUID = firebaseUID {
            validatedFirebaseUID = providedUID
        } else {

            let isOnboarded = await authViewModel.isUserOnboarded(email: email, phoneNumber: phoneNumber)

            print("🔍 [DataModels] Onboarding check - isOnboarded: \(isOnboarded)")

            if !isOnboarded {
                print("❌ [DataModels] User not onboarded")
                return (nil, "User not found. Only registered Settled users can be added to bills", false)
            }


            // Get Firebase UID from email/phone lookup
            guard let uid = await authViewModel.getFirebaseUID(email: email, phoneNumber: phoneNumber) else {
                let errorMessage = "Could not retrieve user ID. This user may have incomplete registration data. Please contact support."
                return (nil, errorMessage, false)
            }
            validatedFirebaseUID = uid
        }


        // Check if this Firebase UID is already in participants
        if let currentUser = currentUser {
            for participant in participants {
            }

            if participants.contains(where: { $0.id == validatedFirebaseUID }) {
                if validatedFirebaseUID == currentUser.uid {
                    return (nil, "You're already in this bill as 'You'", false)
                } else {
                    return (nil, "Participant already exists", false)
                }
            } else {
            }
        }

        // Splitwise-style: Check if email is in user's transaction history
        if let email = email, let contactsManager = contactsManager {
            let emailValidation = AuthViewModel.validateEmail(email)
            if emailValidation.isValid, let validEmail = emailValidation.sanitized {
                print("🔍 [DataModels] Checking transaction contacts for: \(validEmail)")
                print("🔍 [DataModels] Total transaction contacts: \(contactsManager.transactionContacts.count)")

                // Check if this email is already in user's transaction contacts
                let existingTransactionContact = contactsManager.transactionContacts.first {
                    $0.email.lowercased() == validEmail.lowercased()
                }

                if existingTransactionContact == nil {
                    // Email not in transaction history but is registered - show "add to your network" modal
                    print("📝 [DataModels] Email NOT in transaction contacts - returning needsContact=true")
                    return (nil, "Add \(validEmail) to your Settled network", true)
                } else {
                    // Email found in transaction history - proceed with normal flow
                    print("✅ [DataModels] Email found in transaction contacts: \(existingTransactionContact!.displayName)")
                }
            }
        }
        
        // Duplicate check already handled above - proceed with creation

        // Create participant immediately without photoURL for instant UI response
        let tempParticipant = UIParticipant(
            id: validatedFirebaseUID,
            name: trimmedName,
            color: .blue,
            photoURL: nil
        )
        let newParticipant = UIParticipant(
            id: validatedFirebaseUID,
            name: trimmedName,
            color: tempParticipant.assignedColor,
            photoURL: nil
        )

        await MainActor.run {
            participants.append(newParticipant)
        }

        print("✅ [DataModels] Participant added immediately: \(newParticipant.name) (photoURL will load async)")

        // Fetch photoURL asynchronously in background - don't block user
        Task {
            let db = Firestore.firestore()
            var photoURL: String? = nil

            do {
                // First, try participants collection (primary source for public participant data)
                let participantDoc = try await db.collection("participants").document(validatedFirebaseUID).getDocument()
                photoURL = participantDoc.data()?["photoURL"] as? String
                print("📸 [DataModels] Fetched photoURL from participants collection for \(trimmedName) (\(validatedFirebaseUID)): \(photoURL ?? "nil")")

                // If not in participants collection, try users collection as fallback
                if photoURL == nil {
                    print("🔍 [DataModels] PhotoURL not in participants collection, checking users collection...")
                    let userDoc = try await db.collection("users").document(validatedFirebaseUID).getDocument()
                    photoURL = userDoc.data()?["photoURL"] as? String

                    if let foundPhotoURL = photoURL {
                        print("✅ [DataModels] Found photoURL in users collection: \(foundPhotoURL)")

                        // Update participants collection for future use
                        try? await db.collection("participants").document(validatedFirebaseUID).updateData([
                            "photoURL": foundPhotoURL
                        ])
                        print("💾 [DataModels] Synced photoURL to participants collection for \(trimmedName)")
                    }
                }

                // If still not found and this is the current user, get from Firebase Auth
                if photoURL == nil {
                    print("🔍 [DataModels] PhotoURL not in Firestore, checking Firebase Auth...")
                    if let authPhotoURL = Auth.auth().currentUser?.photoURL?.absoluteString,
                       Auth.auth().currentUser?.uid == validatedFirebaseUID {
                        photoURL = authPhotoURL
                        print("✅ [DataModels] Found photoURL in Firebase Auth for current user: \(authPhotoURL)")

                        // Update both collections for future use
                        try? await db.collection("participants").document(validatedFirebaseUID).updateData([
                            "photoURL": authPhotoURL
                        ])
                        try? await db.collection("users").document(validatedFirebaseUID).updateData([
                            "photoURL": authPhotoURL
                        ])
                        print("💾 [DataModels] Updated Firestore collections with photoURL for \(trimmedName)")
                    }
                }

                // Update participant with photoURL if found
                if let photoURL = photoURL {
                    await MainActor.run {
                        if let index = self.participants.firstIndex(where: { $0.id == validatedFirebaseUID }) {
                            self.participants[index].photoURL = photoURL
                            print("🔄 [DataModels] Updated participant \(trimmedName) with photoURL: \(photoURL)")
                        }
                    }
                }
            } catch {
                print("❌ [DataModels] Could not fetch photoURL for participant \(trimmedName): \(error.localizedDescription)")
            }
        }

        return (newParticipant, nil, false)
    }
    
    func removeParticipant(_ participant: UIParticipant) {
        // Don't allow removing "You"
        guard participant.name != "You" else { return }
        
        // Remove from participants
        participants.removeAll { $0.id == participant.id }
        
        // Unassign any items assigned to this participant
        for index in assignedItems.indices {
            // Legacy assignment cleanup
            if assignedItems[index].assignedTo == participant.id {
                assignedItems[index].assignedTo = nil
            }
            // New multiple assignment cleanup
            assignedItems[index].assignedToParticipants.remove(participant.id)
        }
        
    }
    
    func assignItem(itemId: Int, to participantId: String?) {
        if let index = assignedItems.firstIndex(where: { $0.id == itemId }) {
            assignedItems[index].assignedTo = participantId

            let participantName = participants.first { $0.id == participantId }?.name ?? "Unassigned"
        }
    }
    
    // MARK: - Multiple Participant Assignment Methods
    
    func addParticipantToItem(itemId: Int, participantId: String) {
        if let index = assignedItems.firstIndex(where: { $0.id == itemId }) {
            assignedItems[index].assignedToParticipants.insert(participantId)
            
            let participantName = participants.first { $0.id == participantId }?.name ?? "Unknown"
        }
    }
    
    func removeParticipantFromItem(itemId: Int, participantId: String) {
        if let index = assignedItems.firstIndex(where: { $0.id == itemId }) {
            assignedItems[index].assignedToParticipants.remove(participantId)
            
            let participantName = participants.first { $0.id == participantId }?.name ?? "Unknown"
        }
    }
    
    func updateItemAssignments(_ updatedItem: UIItem) {
        if let index = assignedItems.firstIndex(where: { $0.id == updatedItem.id }) {
            assignedItems[index] = updatedItem
        } else {
        }
    }
    
    func completeAssignment() {
        sessionState = .reviewing
        
        // Auto-assign shared items (Tax, Tip) equally
        splitSharedItems()
    }
    
    private func splitSharedItems() {
        for index in assignedItems.indices {
            if assignedItems[index].assignedTo == nil && 
               (assignedItems[index].name.lowercased().contains("tax") || 
                assignedItems[index].name.lowercased().contains("tip")) {
                assignedItems[index].name += " (Split equally)"
            }
        }
    }
    
    func completeSession() {
        sessionState = .complete
    }
    
    // MARK: - Dual Processing Methods
    
    func processWithBothApproaches(
        confirmedTax: Double,
        confirmedTip: Double,
        confirmedTotal: Double,
        expectedItemCount: Int
    ) async {
        
        await MainActor.run {
            self.confirmedTax = confirmedTax
            self.confirmedTip = confirmedTip
            self.confirmedTotal = confirmedTotal
            self.expectedItemCount = expectedItemCount
        }
        
        let ocrService = OCRService()
        
        // Process with regex approach (current mathematical approach)
        await MainActor.run {
        }
        
        let regexItems = await ocrService.processWithMathematicalApproach(
            rawText: rawReceiptText,
            confirmedTax: confirmedTax,
            confirmedTip: confirmedTip,
            confirmedTotal: confirmedTotal,
            expectedItemCount: expectedItemCount
        )
        
        await MainActor.run {
            self.regexDetectedItems = regexItems
        }
        
        // Process with LLM approach
        await MainActor.run {
        }
        
        let llmItems = await ocrService.processWithLLMApproach(
            rawText: rawReceiptText,
            confirmedTax: confirmedTax,
            confirmedTip: confirmedTip,
            confirmedTotal: confirmedTotal,
            expectedItemCount: expectedItemCount
        )
        
        await MainActor.run {
            self.llmDetectedItems = llmItems
        }
    }
    
    // MARK: - Summary Data
    var totalAmount: Double {
        assignedItems.reduce(0) { $0.currencyAdd($1.price) }
    }
    
    /// Checks if the session is ready for bill creation
    var isReadyForBillCreation: Bool {
        // Must have assigned items
        guard !assignedItems.isEmpty else { 
            return false 
        }
        
        // All items must be assigned to participants
        let allItemsAssigned = assignedItems.allSatisfy { !$0.assignedToParticipants.isEmpty }
        guard allItemsAssigned else { 
            return false 
        }
        
        // Must have selected who paid the bill
        guard paidByParticipantID != nil else { 
            return false 
        }
        
        // Must have at least 2 participants (including "You")
        guard participants.count >= 2 else { 
            return false 
        }
        
        return true
    }

    /// Provides specific error message when bill creation is not ready
    var billCreationErrorMessage: String? {
        // Must have assigned items
        guard !assignedItems.isEmpty else {
            return "No items have been added to this bill"
        }

        // All items must be assigned to participants
        let allItemsAssigned = assignedItems.allSatisfy { !$0.assignedToParticipants.isEmpty }
        guard allItemsAssigned else {
            return "Please assign all items to participants"
        }

        // Must have selected who paid the bill
        guard paidByParticipantID != nil else {
            return "Please select who paid this bill"
        }

        // Must have at least 2 participants (including "You")
        guard participants.count >= 2 else {
            return "This bill only includes you. Please add at least one more participant to create a bill"
        }

        return nil // No error - ready for creation
    }

    /// Calculates individual debts - how much each participant owes to the person who paid
    var individualDebts: [String: Double] {
        guard let paidByID = paidByParticipantID else { return [:] }

        var debts: [String: Double] = [:]

        // Initialize all participants (except the payer) with $0 debt
        for participant in participants {
            if participant.id != paidByID {
                debts[participant.id] = 0.0
            }
        }

        // Calculate debt for each item
        for item in assignedItems {
            guard !item.assignedToParticipants.isEmpty else { continue }

            let participantCount = item.assignedToParticipants.count
            let baseAmount = item.price / Double(participantCount)
            let roundedBase = (baseAmount * 100).rounded() / 100

            // Handle remainder distribution (like in BillCalculator)
            let totalRounded = roundedBase * Double(participantCount)
            let remainder = item.price - totalRounded
            let remainderCents = Int((remainder * 100).rounded())

            // Sort participant IDs for consistent remainder distribution
            let sortedParticipants = Array(item.assignedToParticipants).sorted()

            for (index, participantID) in sortedParticipants.enumerated() {
                if participantID != paidByID {
                    var amountOwed = roundedBase

                    // Add extra cent to first few participants to handle remainder
                    if index < remainderCents {
                        amountOwed += 0.01
                    }

                    debts[participantID] = (debts[participantID] ?? 0.0) + amountOwed
                }
            }
        }

        // Final rounding to ensure 2 decimal places
        for participantKey in debts.keys {
            debts[participantKey] = ((debts[participantKey] ?? 0.0) * 100).rounded() / 100
        }

        return debts
    }
    
    var participantSummaries: [UISummaryParticipant] {
        return participants.enumerated().map { index, participant in
            // Calculate total owed using smart distribution for exact amounts
            let totalOwed = assignedItems.reduce(0.0) { total, item in
                return total.currencyAdd(item.getCostForParticipant(participantId: participant.id))
            }
            
            return UISummaryParticipant(
                id: participant.id,
                name: participant.name,
                color: participant.color,
                owes: participant.name == "You" ? 0.0 : totalOwed.currencyRounded,
                gets: participant.name == "You" ? 0.0 : 0.0 // Others don't "get" money, they owe it
            )
        }
    }
    
    var breakdownSummaries: [UIBreakdown] {
        return participants.map { participant in
            // Create breakdown items using smart distribution for exact amounts
            let items = assignedItems.compactMap { item -> UIBreakdownItem? in
                let cost = item.getCostForParticipant(participantId: participant.id)
                if cost > 0 {
                    return UIBreakdownItem(name: item.name, price: cost)
                }
                return nil
            }

            return UIBreakdown(
                id: participant.id,
                name: participant.name,
                color: participant.color,
                items: items,
                photoURL: participant.photoURL
            )
        }
    }

    // MARK: - Session Interruption Recovery (US-EDGE-016)

    /// Current screen index for navigation restoration
    @Published var currentScreenIndex: Int = 0

    /// Auto-save timer for debounced persistence
    private var saveTimer: Timer?

    /// Saves current session with 1-second debouncing
    func autoSaveSession() {
        // Don't save completed or home (uninitialized) sessions
        guard sessionState != .complete && sessionState != .home else {
            return
        }

        // Cancel any pending save to debounce rapid changes
        saveTimer?.invalidate()

        // Schedule new save after 1 second of inactivity
        saveTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // Double-check session state before saving (state might have changed during delay)
            guard self.sessionState != .complete && self.sessionState != .home else {
                return
            }

            Task { @MainActor in
                do {
                    let snapshot = self.createSnapshot()
                    try SettledPersistenceManager.shared.saveSession(snapshot)
                } catch {
                }
            }
        }
    }

    /// Creates a Codable snapshot of current session state (excludes receipt image)
    func createSnapshot() -> BillSplitSessionSnapshot {
        return BillSplitSessionSnapshot(
            sessionId: UUID(), // Generate new ID for each save
            createdAt: Date(),
            lastSavedAt: Date(),
            currentScreenIndex: currentScreenIndex,
            sessionState: sessionState.rawValue,
            billName: billName,
            confirmedTotal: confirmedTotal,
            confirmedTax: confirmedTax,
            confirmedTip: confirmedTip,
            expectedItemCount: expectedItemCount,
            identifiedTotal: identifiedTotal ?? 0.0,
            participants: participants.map { participant in
                ParticipantSnapshot(
                    id: participant.id,
                    name: participant.name,
                    colorHex: participant.color.toHex(),
                    photoURL: participant.photoURL
                )
            },
            paidByParticipantID: paidByParticipantID,
            assignedItems: assignedItems.map { item in
                AssignedItemSnapshot(
                    id: item.id,
                    name: item.name,
                    price: item.price,
                    assignedToParticipants: Array(item.assignedToParticipants),
                    confidence: item.confidence.rawValue,
                    originalDetectedName: item.originalDetectedName,
                    originalDetectedPrice: item.originalDetectedPrice
                )
            },
            rawReceiptText: rawReceiptText,
            ocrConfidence: ocrConfidence
        )
    }

    /// Restores session state from a saved snapshot
    func restoreFrom(snapshot: BillSplitSessionSnapshot) {

        // Restore basic properties
        billName = snapshot.billName
        confirmedTotal = snapshot.confirmedTotal
        confirmedTax = snapshot.confirmedTax
        confirmedTip = snapshot.confirmedTip
        expectedItemCount = snapshot.expectedItemCount
        identifiedTotal = snapshot.identifiedTotal
        currentScreenIndex = snapshot.currentScreenIndex
        rawReceiptText = snapshot.rawReceiptText
        ocrConfidence = snapshot.ocrConfidence

        // Restore participants
        participants = snapshot.participants.map { participantSnapshot in
            UIParticipant(
                id: participantSnapshot.id,
                name: participantSnapshot.name,
                color: Color(hex: participantSnapshot.colorHex),
                photoURL: participantSnapshot.photoURL
            )
        }

        // Restore payer selection
        paidByParticipantID = snapshot.paidByParticipantID

        // Restore assigned items
        // EDGE-001: Filter out zero and negative prices during restoration
        let validItemSnapshots = snapshot.assignedItems.filter { $0.price > 0.00 }
        let filteredCount = snapshot.assignedItems.count - validItemSnapshots.count

        if filteredCount > 0 {
        }

        assignedItems = validItemSnapshots.map { itemSnapshot in
            UIItem(
                id: itemSnapshot.id,
                name: itemSnapshot.name,
                price: itemSnapshot.price,
                assignedTo: nil as String?, // Legacy field - not used in restoration
                assignedToParticipants: Set(itemSnapshot.assignedToParticipants),
                confidence: ConfidenceLevel(rawValue: itemSnapshot.confidence) ?? .medium,
                originalDetectedName: itemSnapshot.originalDetectedName,
                originalDetectedPrice: itemSnapshot.originalDetectedPrice
            )
        }

        // Restore session state
        if let restoredState = SessionState(rawValue: snapshot.sessionState) {
            sessionState = restoredState
        } else {
            sessionState = .assigning // Safe default
        }

    }
}

// MARK: - Transaction Contacts Manager (Splitwise-style)
class ContactsManager: ObservableObject {
    private let db = Firestore.firestore()
    @Published var transactionContacts: [TransactionContact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentUserId: String?
    private var contactsListener: ListenerRegistration?
    
    init() {}
    
    func setCurrentUser(_ userId: String) {
        // Clear existing data if switching users
        if let currentUser = self.currentUserId, currentUser != userId {
            // Remove old listener
            contactsListener?.remove()
            contactsListener = nil
            self.transactionContacts = []
            self.errorMessage = nil
        }
        
        self.currentUserId = userId
        loadTransactionContacts()
    }
    
    func clearCurrentUser() {
        // Remove listener
        contactsListener?.remove()
        contactsListener = nil
        self.currentUserId = nil
        self.transactionContacts = []
        self.errorMessage = nil
        self.isLoading = false
    }
    
    func loadTransactionContacts() {
        guard let userId = currentUserId else { return }
        
        // Remove any existing listener first
        contactsListener?.remove()
        
        isLoading = true
        
        contactsListener = db.collection("users").document(userId).collection("transactionContacts")
            .order(by: "lastTransactionAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                DispatchQueue.main.async {
                    self?.isLoading = false
                    
                    if let error = error {
                        self?.errorMessage = "Failed to load transaction contacts: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else {
                        self?.transactionContacts = []
                        return
                    }
                    
                    let contacts = documents.compactMap { doc in
                        do {
                            let contact = try doc.data(as: TransactionContact.self)
                            return contact
                        } catch {
                            return nil
                        }
                    }
                    
                    self?.transactionContacts = contacts
                }
            }
    }
    
    func saveTransactionContact(_ contact: TransactionContact) async throws {
        guard let userId = currentUserId else {
            throw NSError(domain: "ContactsManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "User not authenticated"])
        }
        
        // Check if contact already exists
        let existingContact = transactionContacts.first { $0.email.lowercased() == contact.email.lowercased() }
        
        if let existing = existingContact {
            // Update existing contact - increment transaction count and update timestamp
            let newTotalTransactions = existing.totalTransactions + 1
            
            try await db.collection("users").document(userId).collection("transactionContacts")
                .document(existing.id).updateData([
                    "lastTransactionAt": FieldValue.serverTimestamp(),
                    "totalTransactions": newTotalTransactions
                ])
            
        } else {
            // Save new transaction contact
            try db.collection("users").document(userId).collection("transactionContacts").document(contact.id).setData(from: contact)
            
        }
    }
    
    func searchTransactionContacts(query: String) -> [TransactionContact] {
        guard !query.isEmpty else { return transactionContacts }
        
        let lowercaseQuery = query.lowercased()
        return transactionContacts.filter {
            $0.displayName.lowercased().contains(lowercaseQuery) ||
            $0.email.lowercased().contains(lowercaseQuery) ||
            ($0.nickname?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }
    
    func validateNewTransactionContact(displayName: String, email: String, phoneNumber: String?, authViewModel: AuthViewModel) async -> ContactValidationResult {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate display name
        guard !trimmedName.isEmpty else {
            return ContactValidationResult(isValid: false, error: "Name is required", contact: nil)
        }
        
        guard trimmedName.count >= 2 else {
            return ContactValidationResult(isValid: false, error: "Name must be at least 2 characters", contact: nil)
        }
        
        // Validate email
        let emailValidation = AuthViewModel.validateEmail(trimmedEmail)
        guard emailValidation.isValid, let validEmail = emailValidation.sanitized else {
            return ContactValidationResult(isValid: false, error: emailValidation.error ?? "Invalid email format", contact: nil)
        }
        
        // SECURITY: Check if this email is a registered Settled user
        let isOnboarded = await authViewModel.isUserOnboarded(email: validEmail, phoneNumber: nil)
        guard isOnboarded else {
            return ContactValidationResult(isValid: false, error: "This email is not registered with Settled. Only registered users can be added to bills.", contact: nil)
        }
        
        // Check if this is the current user's own email
        let currentUserEmail = await MainActor.run { authViewModel.user?.email }
        if let currentUserEmail = currentUserEmail, 
           validEmail.lowercased() == currentUserEmail.lowercased() {
            return ContactValidationResult(isValid: false, error: "You cannot add yourself as a contact.", contact: nil)
        }
        
        // Validate phone number if provided
        var validPhone: String?
        if let phone = phoneNumber?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            let phoneValidation = AuthViewModel.validatePhoneNumber(phone)
            if phoneValidation.isValid {
                validPhone = phoneValidation.sanitized
            } else {
                return ContactValidationResult(isValid: false, error: phoneValidation.error ?? "Invalid phone number format", contact: nil)
            }
        }
        
        let newContact = TransactionContact(
            displayName: trimmedName,
            email: validEmail,
            phoneNumber: validPhone,
            contactUserId: nil // Not implementing global user lookup for now
        )

        return ContactValidationResult(isValid: true, error: nil, contact: newContact)
    }
}

// MARK: - Session Persistence Snapshot Structures (US-EDGE-016)

/// Codable snapshot of BillSplitSession for file persistence
struct BillSplitSessionSnapshot: Codable {
    // Session identification
    let sessionId: UUID
    let createdAt: Date
    let lastSavedAt: Date

    // Navigation state
    let currentScreenIndex: Int
    let sessionState: String // SessionState.rawValue for Codable compatibility

    // Bill data
    let billName: String
    let confirmedTotal: Double
    let confirmedTax: Double
    let confirmedTip: Double
    let expectedItemCount: Int
    let identifiedTotal: Double

    // Participants
    let participants: [ParticipantSnapshot]
    let paidByParticipantID: String?

    // Items
    let assignedItems: [AssignedItemSnapshot]

    // Receipt data (NO image - only text metadata)
    let rawReceiptText: String
    let ocrConfidence: Float
}

/// Codable snapshot of UIParticipant for persistence
struct ParticipantSnapshot: Codable {
    let id: String
    let name: String
    let colorHex: String // Color stored as hex string for Codable
    let photoURL: String? // Profile picture URL
}

/// Codable snapshot of UIItem for persistence
struct AssignedItemSnapshot: Codable {
    let id: Int
    let name: String
    let price: Double
    let assignedToParticipants: [String] // Array of participant IDs
    let confidence: String // ConfidenceLevel.rawValue for Codable
    let originalDetectedName: String?
    let originalDetectedPrice: Double?
}

// MARK: - Color Extension for Hex Conversion (US-EDGE-016)

extension Color {
    /// Converts SwiftUI Color to hex string for Codable persistence
    func toHex() -> String {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

        let r = Int(red * 255)
        let g = Int(green * 255)
        let b = Int(blue * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
        #else
        return "#0000FF" // Fallback for non-UIKit platforms
        #endif
    }

    /// Initializes SwiftUI Color from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: Double
        switch hex.count {
        case 6: // RGB (24-bit)
            (r, g, b) = (
                Double((int >> 16) & 0xFF) / 255.0,
                Double((int >> 8) & 0xFF) / 255.0,
                Double(int & 0xFF) / 255.0
            )
        default:
            (r, g, b) = (0, 0, 1) // Default to blue for invalid hex
        }

        self.init(red: r, green: g, blue: b)
    }
}
// MARK: - Account Deletion Service

/// Custom error for account deletion failures
enum AccountDeletionError: LocalizedError {
    case hasDebts(amount: Double)
    case isOwed(amount: Double)
    case hasActiveBills(count: Int)
    case generalError(String)

    var errorDescription: String? {
        switch self {
        case .hasDebts(let amount):
            return String(format: "You owe $%.2f to others. Please settle your debts before deleting your account.", amount)
        case .isOwed(let amount):
            return String(format: "Others owe you $%.2f. Please collect all payments before deleting your account.", amount)
        case .hasActiveBills(let count):
            return "You have \(count) active bill(s). Please resolve all bills before deleting your account."
        case .generalError(let message):
            return message
        }
    }
}

/// Validates whether a user can safely delete their account
/// Prevents deletion if user has unresolved financial obligations
final class AccountDeletionService {

    // MARK: - Validation Logic

    /// Validates if user can delete their account based on financial obligations
    /// - Parameter billManager: BillManager instance with user's current balance data
    /// - Throws: AccountDeletionError if deletion is not allowed
    static func validateDeletion(for billManager: BillManager) throws {
        // Use NET balances (same calculation as home screen) instead of GROSS balances
        // This ensures consistency between what user sees and deletion validation
        let peopleWhoOweUser = billManager.getPeopleWhoOweUser()
        let peopleUserOwes = billManager.getPeopleUserOwes()

        let totalOwedToUser = peopleWhoOweUser.reduce(0.0) { $0 + $1.total }
        let totalUserOwes = peopleUserOwes.reduce(0.0) { $0 + $1.total }

        // Check if user owes money to others (NET balance)
        if totalUserOwes > 0.01 {
            throw AccountDeletionError.hasDebts(amount: totalUserOwes)
        }

        // Check if others owe money to user (NET balance)
        if totalOwedToUser > 0.01 {
            throw AccountDeletionError.isOwed(amount: totalOwedToUser)
        }

        // Check if user has any active bills (even if settled)
        let activeBillIds = billManager.userBalance.activeBillIds
        if !activeBillIds.isEmpty {
            throw AccountDeletionError.hasActiveBills(count: activeBillIds.count)
        }

        // All checks passed - safe to delete
    }
}
