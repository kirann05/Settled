import SwiftUI
import Firebase
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn
import GoogleSignInSwift
import Foundation
import os.log

// Note: OSLog categories and AppLog functions are defined in DataModels.swift
// to avoid duplicate declarations across files in the same target.

@MainActor
class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var isSignedIn = false
    @Published var isLoading = false
    @Published var errorMessage = ""
    @Published var isInitializing = true
    
    private var isInitialized = false
    
    // SECURITY: Rate limiting for database operations
    private var lastQueryTime: Date = Date.distantPast
    private var queryCount: Int = 0
    private let maxQueriesPerMinute: Int = 30
    private let minTimeBetweenQueries: TimeInterval = 1.0 // 1 second
    
    // Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw NSError(domain: "TimeoutError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    
    // Debug function to create test users
    func createTestUser(email: String, displayName: String, phoneNumber: String? = nil) async {
        guard let db = Firestore.firestore() as Firestore? else {
            AppLog.firebaseError("Firestore not available")
            #if DEBUG
            #endif
            return
        }
        
        do {
            let testUID = "test_\(UUID().uuidString.prefix(8))"
            let userRef = db.collection("users").document(testUID)
            
            var userData: [String: Any] = [
                "uid": testUID,
                "email": email.lowercased(),
                "displayName": displayName,
                "authProvider": "test",
                "createdAt": FieldValue.serverTimestamp(),
                "lastSignInAt": FieldValue.serverTimestamp()
            ]
            
            if let phoneNumber = phoneNumber {
                userData["phoneNumber"] = phoneNumber
            }
            
            try await userRef.setData(userData, merge: true)
            AppLog.authSuccess("Test user created", userEmail: email)
            #if DEBUG
            #endif
            
        } catch {
            AppLog.authError("Failed to create test user", error: error)
            #if DEBUG
            #endif
        }
    }
    
    // SECURITY: Rate limiting check
    private func checkRateLimit() async -> Bool {
        let now = Date()
        
        // Reset counter if more than a minute has passed
        if now.timeIntervalSince(lastQueryTime) > 60 {
            queryCount = 0
        }
        
        // Check if we're within rate limits
        guard queryCount < maxQueriesPerMinute else {
            AppLog.authWarning("Rate limit exceeded. Please wait before making more requests.")
            #if DEBUG
            #endif
            return false
        }
        
        // Check minimum time between queries
        if now.timeIntervalSince(lastQueryTime) < minTimeBetweenQueries {
            let waitTime = minTimeBetweenQueries - now.timeIntervalSince(lastQueryTime)
            AppLog.authWarning("Rate limiting: waiting \(waitTime) seconds before proceeding")
            #if DEBUG
            #endif
            // Wait for the required time and then proceed
            try? await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
        }
        
        // Update rate limiting counters
        lastQueryTime = now
        queryCount += 1
        return true
    }
    
    // SECURE Input validation functions
    nonisolated static func validateEmail(_ email: String?) -> (isValid: Bool, sanitized: String?, error: String?) {
        guard let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
            return (false, nil, "Email cannot be empty")
        }
        
        // Basic length check
        guard email.count <= 254 else {
            return (false, nil, "Email too long (max 254 characters)")
        }
        
        // Email regex pattern - RFC 5322 compliant
        let emailRegex = #"^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"#
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        
        guard emailPredicate.evaluate(with: email) else {
            return (false, nil, "Invalid email format")
        }
        
        // Additional security checks
        let lowercaseEmail = email.lowercased()
        
        // Block potentially malicious patterns
        let suspiciousPatterns = ["javascript:", "data:", "<script", "%3cscript"]
        for pattern in suspiciousPatterns {
            if lowercaseEmail.contains(pattern) {
                return (false, nil, "Invalid email format")
            }
        }
        
        return (true, lowercaseEmail, nil)
    }
    
    nonisolated static func validatePhoneNumber(_ phone: String?) -> (isValid: Bool, sanitized: String?, error: String?) {
        guard let phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty else {
            return (false, nil, "Phone number cannot be empty")
        }
        
        // Remove all non-digit characters for validation
        let digitsOnly = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        
        // Basic length checks
        guard digitsOnly.count >= 10 && digitsOnly.count <= 15 else {
            return (false, nil, "Phone number must be 10-15 digits")
        }
        
        // Simple international format check
        let phoneRegex = #"^\+?[1-9]\d{9,14}$"#
        let phonePredicate = NSPredicate(format: "SELF MATCHES %@", phoneRegex)
        
        guard phonePredicate.evaluate(with: digitsOnly) else {
            return (false, nil, "Invalid phone number format")
        }
        
        // Security checks - block suspicious patterns
        let suspiciousPatterns = ["javascript:", "data:", "<script"]
        for pattern in suspiciousPatterns {
            if phone.lowercased().contains(pattern) {
                return (false, nil, "Invalid phone number format")
            }
        }
        
        return (true, digitsOnly, nil)
    }
    
    nonisolated static func validateDisplayName(_ name: String?) -> (isValid: Bool, sanitized: String?, error: String?) {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return (false, nil, "Name cannot be empty")
        }
        
        guard name.count <= 100 else {
            return (false, nil, "Name too long (max 100 characters)")
        }
        
        // Only allow letters, numbers, spaces, and common punctuation
        let allowedCharacterSet = CharacterSet.alphanumerics.union(.whitespaces).union(CharacterSet(charactersIn: ".-'"))
        guard name.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else {
            return (false, nil, "Name contains invalid characters")
        }
        
        // Security checks
        let suspiciousPatterns = ["javascript:", "data:", "<script", "<?", "%3c"]
        for pattern in suspiciousPatterns {
            if name.lowercased().contains(pattern) {
                return (false, nil, "Invalid name format")
            }
        }
        
        return (true, name, nil)
    }
    
    // SECURE User validation service - checks both participants and users collections with auto-migration
    func isUserOnboarded(email: String? = nil, phoneNumber: String? = nil) async -> Bool {
        // SECURITY: Check rate limiting first
        guard await checkRateLimit() else {
            AppLog.authError("Rate limit exceeded for user validation")
            #if DEBUG
            #endif
            return false
        }
        
        guard let db = Firestore.firestore() as Firestore? else {
            AppLog.firebaseError("Firestore not available")
            #if DEBUG
            #endif
            return false
        }
        
        do {
            AppLog.debug("Checking user onboarding status...", category: .authentication)
            #if DEBUG
            #endif
            
            // Validate and check by email first
            if let email = email {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {
                    
                    // First check the new participants collection
                    let participantsRef = db.collection("participants")
                    let participantEmailQuery = participantsRef.whereField("email", isEqualTo: sanitizedEmail)
                    let participantSnapshot = try await participantEmailQuery.getDocuments(source: .default)
                    
                    if !participantSnapshot.isEmpty {
                        AppLog.authSuccess("User found in participants collection", userEmail: sanitizedEmail)
                        #if DEBUG
                        #endif
                        return true
                    }
                    
                    // If not found in participants, check the original users collection
                    let usersRef = db.collection("users")
                    let userEmailQuery = usersRef.whereField("email", isEqualTo: sanitizedEmail)
                    let userSnapshot = try await userEmailQuery.getDocuments(source: .default)
                    
                    if !userSnapshot.isEmpty {
                        AppLog.authSuccess("User found in users collection", userEmail: sanitizedEmail)
                        #if DEBUG
                        #endif
                        
                        // Auto-migrate: Create participant record for existing user
                        if let userDoc = userSnapshot.documents.first {
                            await autoMigrateUserToParticipant(userDoc: userDoc, db: db)
                        }
                        
                        return true
                    }
                } else {
                    return false
                }
            }
            
            // Validate and check by phone number if email not found
            if let phoneNumber = phoneNumber {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {
                    
                    // First check the new participants collection
                    let participantsRef = db.collection("participants")
                    let participantPhoneQuery = participantsRef.whereField("phoneNumber", isEqualTo: sanitizedPhone)
                    let participantSnapshot = try await participantPhoneQuery.getDocuments(source: .default)
                    
                    if !participantSnapshot.isEmpty {
                        AppLog.authSuccess("User found with phone in participants")
                        #if DEBUG
                        #endif
                        return true
                    }
                    
                    // If not found in participants, check the original users collection
                    let usersRef = db.collection("users")
                    let userPhoneQuery = usersRef.whereField("phoneNumber", isEqualTo: sanitizedPhone)
                    let userSnapshot = try await userPhoneQuery.getDocuments(source: .default)
                    
                    if !userSnapshot.isEmpty {
                        AppLog.authSuccess("User found with phone in users collection")
                        #if DEBUG
                        #endif
                        
                        // Auto-migrate: Create participant record for existing user
                        if let userDoc = userSnapshot.documents.first {
                            await autoMigrateUserToParticipant(userDoc: userDoc, db: db)
                        }
                        
                        return true
                    }
                } else {
                    return false
                }
            }
            
            return false
            
        } catch {
            AppLog.authError("Error checking user onboarding status", error: error)
            #if DEBUG
            #endif
            return false
        }
    }

    // Get Firebase UID for validated user (used for participant ID consistency)
    func getFirebaseUID(email: String? = nil, phoneNumber: String? = nil) async -> String? {
        // SECURITY: Check rate limiting first
        guard await checkRateLimit() else {
            AppLog.authError("Rate limit exceeded for Firebase UID lookup")
            #if DEBUG
            #endif
            return nil
        }

        guard let db = Firestore.firestore() as Firestore? else {
            AppLog.firebaseError("Firestore not available")
            #if DEBUG
            #endif
            return nil
        }

        do {
            AppLog.debug("Getting Firebase UID for user...", category: .authentication)
            #if DEBUG
            #endif

            // Validate and check by email first
            if let email = email {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {

                    // First check the participants collection
                    let participantsRef = db.collection("participants")
                    let participantEmailQuery = participantsRef.whereField("email", isEqualTo: sanitizedEmail)
                    let participantSnapshot = try await participantEmailQuery.getDocuments(source: .default)


                    if let participantDoc = participantSnapshot.documents.first {
                        let firebaseUID = participantDoc.documentID
                        let data = participantDoc.data()

                        AppLog.authSuccess("Firebase UID found in participants collection", userEmail: sanitizedEmail)
                        #if DEBUG
                        #endif
                        return firebaseUID
                    }

                    // If not found in participants, check the users collection
                    let usersRef = db.collection("users")
                    let userEmailQuery = usersRef.whereField("email", isEqualTo: sanitizedEmail)
                    let userSnapshot = try await userEmailQuery.getDocuments(source: .default)


                    if let userDoc = userSnapshot.documents.first {
                        let firebaseUID = userDoc.documentID
                        let data = userDoc.data()

                        AppLog.authSuccess("Firebase UID found in users collection", userEmail: sanitizedEmail)
                        #if DEBUG
                        #endif
                        return firebaseUID
                    }

                } else {
                    return nil
                }
            }

            // Validate and check by phone number if email not found
            if let phoneNumber = phoneNumber {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {

                    // First check the participants collection
                    let participantsRef = db.collection("participants")
                    let participantPhoneQuery = participantsRef.whereField("phoneNumber", isEqualTo: sanitizedPhone)
                    let participantSnapshot = try await participantPhoneQuery.getDocuments(source: .default)

                    if let participantDoc = participantSnapshot.documents.first {
                        let firebaseUID = participantDoc.documentID
                        AppLog.authSuccess("Firebase UID found with phone in participants")
                        #if DEBUG
                        #endif
                        return firebaseUID
                    }

                    // If not found in participants, check the users collection
                    let usersRef = db.collection("users")
                    let userPhoneQuery = usersRef.whereField("phoneNumber", isEqualTo: sanitizedPhone)
                    let userSnapshot = try await userPhoneQuery.getDocuments(source: .default)

                    if let userDoc = userSnapshot.documents.first {
                        let firebaseUID = userDoc.documentID
                        AppLog.authSuccess("Firebase UID found with phone in users collection")
                        #if DEBUG
                        #endif
                        return firebaseUID
                    }
                } else {
                    return nil
                }
            }

            return nil

        } catch {
            AppLog.authError("Error getting Firebase UID", error: error)
            #if DEBUG
            #endif
            return nil
        }
    }

    // Auto-migration helper: Creates participant record from existing user data
    private func autoMigrateUserToParticipant(userDoc: DocumentSnapshot, db: Firestore) async {
        do {
            let userData = userDoc.data() ?? [:]
            let userId = userDoc.documentID
            
            
            let participantRef = db.collection("participants").document(userId)
            
            // Check if participant record already exists
            let existingParticipant = try await participantRef.getDocument(source: .default)
            if existingParticipant.exists {
                return
            }
            
            // Create participant record with validated data
            var participantData: [String: Any] = [
                "isActive": true,
                "createdAt": userData["createdAt"] ?? FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp()
            ]
            
            // Validate and add display name
            if let displayName = userData["displayName"] as? String {
                let nameValidation = AuthViewModel.validateDisplayName(displayName)
                participantData["displayName"] = nameValidation.isValid ? nameValidation.sanitized! : "Unknown User"
            } else {
                participantData["displayName"] = "Unknown User"
            }
            
            // Validate and add email if available
            if let email = userData["email"] as? String {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {
                    participantData["email"] = sanitizedEmail
                }
            }
            
            // Validate and add phone number if available
            if let phoneNumber = userData["phoneNumber"] as? String {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {
                    participantData["phoneNumber"] = sanitizedPhone
                }
            }
            
            try await participantRef.setData(participantData, merge: true)
            
        } catch {
            // Don't fail the validation - just log the error
        }
    }
    
    init() {
        // Defer auth state check to avoid blocking app startup and ensure Firebase is ready
        Task {
            // Small delay to ensure Firebase is fully configured
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
            await checkAuthState()
        }
    }
    
    private func checkAuthState() async {
        // Only check auth state once Firebase is configured
        guard !isInitialized else { return }
        isInitialized = true
        
        
        // Wait for Firebase to be fully ready
        var retries = 0
        while FirebaseApp.app() == nil && retries < 50 {
            try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 second
            retries += 1
        }
        
        if FirebaseApp.app() == nil {
            await MainActor.run {
                self.isInitializing = false
            }
            return
        }
        
        
        // Check if we have a current user
        if let user = Auth.auth().currentUser {
            await MainActor.run {
                self.user = user
                self.isSignedIn = true
                self.isInitializing = false
            }
            
            // MIGRATION: Ensure participant record exists for existing users
            Task.detached(priority: .userInitiated) { [weak self] in
                await self?.ensureParticipantRecordExists(for: user)
            }
        } else {
            await MainActor.run {
                self.isInitializing = false
            }
        }
    }

    func signInWithGoogle() async {

        // Ensure we're not already loading
        guard !isLoading else {
            return
        }

        await MainActor.run {
            self.isLoading = true
            self.errorMessage = ""
        }

        // Add small delay to prevent rapid successive calls
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second

        // Get root view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            await MainActor.run {
                self.errorMessage = "Unable to get root view controller"
                self.isLoading = false
            }
            return
        }


        do {
            // Use the Google Sign-In SDK (shows Google's UI)
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
            // Check if we're still in loading state (user might have cancelled)
            guard isLoading else {
                return
            }
            
            guard let idToken = result.user.idToken?.tokenString else {
                await MainActor.run {
                    self.errorMessage = "Failed to get ID token from Google"
                    self.isLoading = false
                }
                return
            }
            
            
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            
            let authResult = try await Auth.auth().signIn(with: credential)

            // Create user record in background (non-blocking)
            Task.detached(priority: .userInitiated) { [weak self] in
                do {
                    try await self?.createUserRecord(authResult: authResult)
                    try await self?.createParticipantRecord(authResult: authResult)

                    // MIGRATION: Auto-migrate existing users on login
                    await self?.performAutoMigrationIfNeeded(authResult: authResult)

                } catch {
                    AppLog.authError("Background record creation failed", error: error)
                    #if DEBUG
                    #endif
                }
            }

            // Update UI state immediately
            await MainActor.run {
                self.user = authResult.user
                self.isSignedIn = true
                self.isLoading = false
            }
            
            // Update FCM token for push notifications (async, don't block UI)
            Task {
                await FCMTokenManager.shared.validateAndRefreshToken()
            }
            
        } catch {
            AppLog.authError("Sign-in error", error: error)
            #if DEBUG
            #endif
            await MainActor.run {
                // Handle specific error types
                if let nsError = error as NSError? {
                    switch nsError.code {
                    case -5: // User cancelled
                        self.errorMessage = ""
                    default:
                        self.errorMessage = error.localizedDescription
                    }
                } else {
                    self.errorMessage = error.localizedDescription
                }
                self.isLoading = false
            }
        }
    }

    private func createUserRecord(authResult: AuthDataResult) async throws {
        
        let db = Firestore.firestore()
        let userRef = db.collection("users").document(authResult.user.uid)
        
        // Set a timeout for Firestore operations to prevent hanging
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
            throw NSError(domain: "FirestoreTimeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Firestore operation timed out"])
        }
        
        let firestoreTask = Task {
            do {
                // Check if user already exists with offline support
                let document = try await userRef.getDocument(source: .default)
                
                if !document.exists {
                    
                    var userData: [String: Any] = [
                        "uid": authResult.user.uid,
                        "email": authResult.user.email ?? "",
                        "displayName": authResult.user.displayName ?? "",
                        "authProvider": "google.com",
                        "createdAt": FieldValue.serverTimestamp(),
                        "lastSignInAt": FieldValue.serverTimestamp()
                    ]

                    // Add phone number if available from Google OAuth
                    if let phoneNumber = authResult.user.phoneNumber {
                        userData["phoneNumber"] = phoneNumber
                    }

                    // Add photoURL if available from Google OAuth
                    if let photoURL = authResult.user.photoURL {
                        userData["photoURL"] = photoURL.absoluteString
                    }
                    
                    let cleanedUserData = userData.compactMapValues { $0 }
                    
                    try await userRef.setData(cleanedUserData, merge: true)
                } else {
                    // Update existing user record with latest data
                    var updateData: [String: Any] = [
                        "lastSignInAt": FieldValue.serverTimestamp()
                    ]

                    // Update photoURL if available from Google OAuth
                    if let photoURL = authResult.user.photoURL {
                        updateData["photoURL"] = photoURL.absoluteString
                    }

                    try await userRef.updateData(updateData)
                }
            } catch let error as NSError {
                // Handle specific Firestore errors
                if error.domain == FirestoreErrorDomain {
                    switch error.code {
                    case FirestoreErrorCode.unavailable.rawValue:
                        var userData: [String: Any] = [
                            "uid": authResult.user.uid,
                            "email": authResult.user.email ?? "",
                            "displayName": authResult.user.displayName ?? "",
                            "authProvider": "google.com",
                            "lastSignInAt": FieldValue.serverTimestamp(),
                            "createdAt": FieldValue.serverTimestamp()
                        ]

                        // Add phone number if available from Google OAuth
                        if let phoneNumber = authResult.user.phoneNumber {
                            userData["phoneNumber"] = phoneNumber
                        }

                        // Add photoURL if available from Google OAuth
                        if let photoURL = authResult.user.photoURL {
                            userData["photoURL"] = photoURL.absoluteString
                        }
                        
                        let cleanedUserData = userData.compactMapValues { $0 }
                        
                        try await userRef.setData(cleanedUserData, merge: true)
                    
                    case FirestoreErrorCode.permissionDenied.rawValue:
                        // Don't throw error, just log it
                        return
                    
                    default:
                        AppLog.firebaseError("Firestore error", error: error)
                        #if DEBUG
                        #endif
                        throw error
                    }
                } else {
                    throw error
                }
            }
        }
        
        // Race the timeout against the Firestore operation
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await timeoutTask.value
                }
                group.addTask {
                    try await firestoreTask.value
                }
                
                // Wait for the first task to complete
                try await group.next()
                
                // Cancel the remaining task
                group.cancelAll()
            }
        } catch {
            // Don't rethrow - we want authentication to succeed even if Firestore fails
        }
    }
    
    // SECURE: Create participant record with validated minimal public data only
    private func createParticipantRecord(authResult: AuthDataResult) async throws {
        
        let db = Firestore.firestore()
        let participantRef = db.collection("participants").document(authResult.user.uid)
        
        // Check if participant record already exists
        let document = try await participantRef.getDocument(source: .default)
        
        if !document.exists {
            
            // Validate display name
            let nameValidation = AuthViewModel.validateDisplayName(authResult.user.displayName)
            let validatedDisplayName = nameValidation.isValid ? nameValidation.sanitized! : "Unknown User"
            
            // Only store minimal public information needed for participant validation
            var participantData: [String: Any] = [
                "displayName": validatedDisplayName,
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp()
            ]
            
            // Validate and add email if available
            if let email = authResult.user.email {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {
                    participantData["email"] = sanitizedEmail
                } else {
                }
            }
            
            // Validate and add phone number if available
            if let phoneNumber = authResult.user.phoneNumber {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {
                    participantData["phoneNumber"] = sanitizedPhone
                } else {
                }
            }

            // Add photoURL if available from Google OAuth
            if let photoURL = authResult.user.photoURL {
                participantData["photoURL"] = photoURL.absoluteString
            }

            try await participantRef.setData(participantData, merge: true)
        } else {
            // Update existing participant record with latest data
            var updateData: [String: Any] = [
                "lastActiveAt": FieldValue.serverTimestamp(),
                "isActive": true
            ]

            // Update photoURL if available from Google OAuth
            if let photoURL = authResult.user.photoURL {
                updateData["photoURL"] = photoURL.absoluteString
                print("💾 [AuthViewModel] Updating participant record with photoURL: \(photoURL.absoluteString)")
            } else {
                print("⚠️ [AuthViewModel] No photoURL available from Firebase Auth for user: \(authResult.user.uid)")
            }

            try await participantRef.updateData(updateData)
            print("✅ [AuthViewModel] Participant record updated successfully for user: \(authResult.user.uid)")
        }
    }
    
    // MIGRATION: Auto-migrate current user's data when they log in
    private func performAutoMigrationIfNeeded(authResult: AuthDataResult) async {
        do {
            let db = Firestore.firestore()
            let userId = authResult.user.uid
            
            // Check if participant record already exists
            let participantRef = db.collection("participants").document(userId)
            let participantDoc = try await participantRef.getDocument(source: .default)
            
            if !participantDoc.exists {
                
                // Get current user's data from users collection (allowed since it's their own data)
                let userRef = db.collection("users").document(userId)
                let userDoc = try await userRef.getDocument(source: .default)
                
                if userDoc.exists {
                    await autoMigrateUserToParticipant(userDoc: userDoc, db: db)
                } else {
                }
            } else {
            }
            
        } catch {
            // Don't fail login - just log the error
        }
    }
    
    // MIGRATION: Ensure participant record exists for any authenticated user
    private func ensureParticipantRecordExists(for user: User) async {
        do {
            let db = Firestore.firestore()
            let userId = user.uid
            
            AppLog.debug("Checking if participant record exists for current user...", category: .authentication)
            #if DEBUG
            #endif
            
            // Check if participant record already exists
            let participantRef = db.collection("participants").document(userId)
            let participantDoc = try await participantRef.getDocument(source: .default)
            
            if !participantDoc.exists {
                
                // Get current user's data from users collection (allowed since it's their own data)
                let userRef = db.collection("users").document(userId)
                let userDoc = try await userRef.getDocument(source: .default)
                
                if userDoc.exists {
                    await autoMigrateUserToParticipant(userDoc: userDoc, db: db)
                } else {
                    // Create participant record from auth user data directly
                    await createParticipantFromAuth(user: user, db: db)
                }
            } else {
            }
            
        } catch {
            // Don't fail - just log the error
        }
    }
    
    // Create participant record directly from Auth user data
    private func createParticipantFromAuth(user: User, db: Firestore) async {
        do {
            let participantRef = db.collection("participants").document(user.uid)
            
            // Validate display name
            let nameValidation = AuthViewModel.validateDisplayName(user.displayName)
            let validatedDisplayName = nameValidation.isValid ? nameValidation.sanitized! : "Unknown User"
            
            // Create participant record with validated data
            var participantData: [String: Any] = [
                "displayName": validatedDisplayName,
                "isActive": true,
                "createdAt": FieldValue.serverTimestamp(),
                "lastActiveAt": FieldValue.serverTimestamp()
            ]
            
            // Validate and add email if available
            if let email = user.email {
                let emailValidation = AuthViewModel.validateEmail(email)
                if emailValidation.isValid, let sanitizedEmail = emailValidation.sanitized {
                    participantData["email"] = sanitizedEmail
                }
            }
            
            // Validate and add phone number if available
            if let phoneNumber = user.phoneNumber {
                let phoneValidation = AuthViewModel.validatePhoneNumber(phoneNumber)
                if phoneValidation.isValid, let sanitizedPhone = phoneValidation.sanitized {
                    participantData["phoneNumber"] = sanitizedPhone
                }
            }

            // Add photoURL if available from Google OAuth
            if let photoURL = user.photoURL {
                participantData["photoURL"] = photoURL.absoluteString
            }

            try await participantRef.setData(participantData, merge: true)
            
        } catch {
        }
    }
    
    func signOut() {
        do {
            try Auth.auth().signOut()
            GIDSignIn.sharedInstance.signOut()
            self.user = nil
            self.isSignedIn = false
            self.errorMessage = ""
            self.isLoading = false

            // Reset initialization state to allow re-checking auth state
            self.isInitialized = false

        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    // MARK: - Account Deletion

    /// Validates and deletes user account with financial obligation checks
    /// - Parameter billManager: BillManager instance with user's balance data
    /// - Throws: AccountDeletionError if validation fails, or other errors during deletion
    func deleteAccount(billManager: BillManager) async throws {

        // Step 1: Validate deletion is allowed (throws if blocked)
        try AccountDeletionService.validateDeletion(for: billManager)

        // Step 2: Get current user
        guard let currentUser = Auth.auth().currentUser else {
            throw AccountDeletionError.generalError("No authenticated user found")
        }

        // Step 3: Delete user data from Firestore first
        let db = Firestore.firestore()
        let userId = currentUser.uid


        // Delete from users collection
        try await db.collection("users").document(userId).delete()

        // Delete from participants collection
        try await db.collection("participants").document(userId).delete()

        // Step 4: Delete Firebase Auth account
        try await currentUser.delete()

        // Step 5: Sign out from Google
        GIDSignIn.sharedInstance.signOut()

        // Step 6: Clear local state
        await MainActor.run {
            self.user = nil
            self.isSignedIn = false
            self.errorMessage = ""
            self.isLoading = false
            self.isInitialized = false
        }

    }
}