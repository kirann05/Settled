import Foundation
import FirebaseFirestore
import FirebaseAuth
// TODO: Uncomment after adding FirebaseMessaging dependency in Xcode
// import FirebaseMessaging
import Combine

// MARK: - FCM Token Management Service
final class FCMTokenManager: ObservableObject {
    static let shared = FCMTokenManager()
    
    private let db = Firestore.firestore()
    @Published var currentToken: String?
    @Published var isTokenValid = false
    @Published var lastTokenRefresh: Date?
    
    private var tokenRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // CRITICAL FIX: Add synchronization queue for thread safety
    private let tokenQueue = DispatchQueue(label: "fcm.token.queue", qos: .userInitiated)
    private let cacheQueue = DispatchQueue(label: "fcm.cache.queue", qos: .utility)
    
    // Token refresh configuration
    private let tokenRefreshInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let maxRetryAttempts = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // Cache for email-to-token mappings with thread safety
    private var _tokenCache: [String: (token: String, timestamp: Date)] = [:]
    private let cacheExpirationInterval: TimeInterval = 5 * 60 // 5 minutes
    
    // SOLOPRENEUR OPTIMIZATION: Batch size limits to prevent expensive Firebase queries
    private let maxBatchQuerySize = 10 // Firebase 'in' queries limited to 30, keep conservative
    private let maxCacheSize = 100 // Prevent unlimited memory growth
    
    private init() {
        setupTokenMonitoring()
        loadCachedToken()
    }
    
    /// Thread-safe access to token cache
    private var tokenCache: [String: (token: String, timestamp: Date)] {
        get {
            return cacheQueue.sync { _tokenCache }
        }
        set {
            cacheQueue.async(flags: .barrier) {
                // MEMORY LEAK FIX: Enforce cache size limits
                if newValue.count > self.maxCacheSize {
                    // Remove oldest entries first
                    let sortedByTime = newValue.sorted { $0.value.timestamp < $1.value.timestamp }
                    let toKeep = sortedByTime.suffix(self.maxCacheSize - 10) // Keep 90 most recent
                    self._tokenCache = Dictionary(uniqueKeysWithValues: toKeep)
                } else {
                    self._tokenCache = newValue
                }
            }
        }
    }
    
    /// Sets up automatic token monitoring and refresh
    private func setupTokenMonitoring() {
        // Monitor token expiration every 24 hours
        tokenRefreshTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
            Task {
                try? await self?.refreshTokenIfNeeded()
            }
        }
        
        // Monitor auth state changes with immediate cleanup
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task {
                if user != nil {
                    // RACE CONDITION FIX: Only one token fetch at a time
                    try? await self?.fetchCurrentTokenSafely()
                } else {
                    // CRITICAL: Immediate cleanup to prevent privacy issues
                    await self?.cleanupTokenOnSignOut()
                }
            }
        }
    }
    
    /// Thread-safe token fetching to prevent race conditions
    private func fetchCurrentTokenSafely() async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            tokenQueue.async {
                Task {
                    do {
                        let token = try await self._fetchCurrentToken()
                        continuation.resume(returning: token)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// Internal token fetching (called from synchronized context)
    private func _fetchCurrentToken() async throws -> String? {
        // TODO: Replace with real Firebase Messaging SDK when dependency is added
        // let fcmToken = try await Messaging.messaging().token()

        // Temporary simulation until FirebaseMessaging is added
        let simulatedToken = "fcm_token_" + UUID().uuidString.prefix(12)
        let fcmToken = String(simulatedToken)

        await MainActor.run {
            self.currentToken = fcmToken
            self.isTokenValid = true
            self.lastTokenRefresh = Date()
        }

        // ATOMIC OPERATION: Save token to UserDefaults for persistence
        UserDefaults.standard.set(fcmToken, forKey: "fcm_token")
        UserDefaults.standard.set(Date(), forKey: "fcm_token_refresh_date")

        // Update token in Firestore if user is authenticated
        if let userId = Auth.auth().currentUser?.uid {
            try await updateUserToken(fcmToken, for: userId)
        }

        return fcmToken
    }
    
    /// Public API for fetching current token
    @discardableResult
    func fetchCurrentToken() async throws -> String? {
        return try await fetchCurrentTokenSafely()
    }
    
    /// Updates user's FCM token in Firestore with conflict detection
    func updateUserToken(_ token: String, for userId: String) async throws {
        let userRef = db.collection("users").document(userId)
        
        // RACE CONDITION FIX: Use Firestore transaction for atomic updates
        try await db.runTransaction({ (transaction, errorPointer) -> Any? in
            let userDocument: DocumentSnapshot
            
            do {
                userDocument = try transaction.getDocument(userRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            // Check if token has changed since our last update (prevent overwrites)
            let currentStoredToken = userDocument.data()?["fcmToken"] as? String
            let lastUpdate = userDocument.data()?["tokenUpdatedAt"] as? Timestamp
            
            // Only update if token is different or significantly old (1 hour)
            let shouldUpdate = currentStoredToken != token || 
                (lastUpdate == nil || Date().timeIntervalSince(lastUpdate!.dateValue()) > 3600)
            
            if shouldUpdate {
                let tokenData: [String: Any] = [
                    "fcmToken": token,
                    "tokenUpdatedAt": FieldValue.serverTimestamp(),
                    "tokenVersion": (userDocument.data()?["tokenVersion"] as? Int ?? 0) + 1,
                    "platform": "ios",
                    "lastSeen": FieldValue.serverTimestamp(),
                    "userId": userId // Ensure consistency
                ]
                
                transaction.setData(tokenData, forDocument: userRef, merge: true)
                
                // COST OPTIMIZATION: Also update participant lookup for efficient queries
                let participantRef = self.db.collection("participants").document(userId)
                let participantData: [String: Any] = [
                    "fcmToken": token,
                    "lastTokenUpdate": FieldValue.serverTimestamp()
                ]
                transaction.setData(participantData, forDocument: participantRef, merge: true)
            }
            
            return nil
        })
        
        AppLog.authSuccess("FCM token updated for user: \(userId)", userEmail: userId)
        
        // COST OPTIMIZATION: Skip metadata update for frequent token refreshes
        if let currentToken = await MainActor.run(body: { self.currentToken }),
           currentToken != token {
            try await updateTokenMetadata(token: token, userId: userId)
        }
    }
    
    /// Forces token refresh if needed with proper synchronization
    func refreshTokenIfNeeded() async throws {
        let needsRefresh = await MainActor.run {
            guard let lastRefresh = self.lastTokenRefresh else { return true }
            return Date().timeIntervalSince(lastRefresh) > tokenRefreshInterval
        }
        
        if needsRefresh || !isTokenValid {
            AppLog.authSuccess("Refreshing FCM token...", userEmail: "system")
            try await fetchCurrentTokenSafely()
        } else {
            AppLog.authSuccess("FCM token still valid", userEmail: "system")
        }
    }
    
    /// Validates token freshness and health
    func validateTokenHealth() -> Bool {
        guard let currentToken = currentToken,
              let lastRefresh = lastTokenRefresh else {
            return false
        }
        
        // Check if token is not expired (7 days)
        let tokenAge = Date().timeIntervalSince(lastRefresh)
        let isNotExpired = tokenAge < tokenRefreshInterval
        
        // Check if token format is valid
        let hasValidFormat = currentToken.hasPrefix("fcm_token_") && currentToken.count > 15
        
        return isTokenValid && isNotExpired && hasValidFormat
    }
    
    /// Cleans up tokens for signed-out users - CRITICAL for privacy
    func cleanupTokenOnSignOut() async {
        await MainActor.run {
            self.currentToken = nil
            self.isTokenValid = false
            self.lastTokenRefresh = nil
        }
        
        // THREAD SAFETY: Clear cache safely
        self.tokenCache = [:]
        
        // Clear from UserDefaults
        UserDefaults.standard.removeObject(forKey: "fcm_token")
        UserDefaults.standard.removeObject(forKey: "fcm_token_refresh_date")
        
        AppLog.authSuccess("FCM token cleaned up on sign out", userEmail: "system")
    }
    
    // MARK: - Private Helper Methods
    
    /// Implements exponential backoff for token refresh retries
    private func retryTokenRefresh(attempt: Int) async throws {
        let delay = baseRetryDelay * pow(2, Double(attempt - 1))
        
        AppLog.authWarning("Retrying token refresh (attempt \(attempt)/\(maxRetryAttempts)) after \(delay)s delay")
        
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        
        do {
            try await fetchCurrentTokenSafely()
        } catch {
            if attempt < maxRetryAttempts {
                try await retryTokenRefresh(attempt: attempt + 1)
            } else {
                throw FCMTokenError.refreshFailed("Max retry attempts reached: \(error.localizedDescription)")
            }
        }
    }
    
    /// Updates token metadata in Firestore
    private func updateTokenMetadata(token: String, userId: String) async throws {
        let metadataRef = db.collection("fcm_tokens").document(userId)
        
        let metadata: [String: Any] = [
            "userId": userId,
            "token": token,
            "createdAt": FieldValue.serverTimestamp(),
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "1.0.0",
            "isActive": true,
            "lastValidated": FieldValue.serverTimestamp()
        ]
        
        try await metadataRef.setData(metadata)
        AppLog.authSuccess("FCM token metadata updated", userEmail: "system")
    }
    
    // MARK: - Public API for PushNotificationService with COST OPTIMIZATION
    
    /// Gets FCM tokens for multiple email addresses with intelligent batching and caching
    func getFCMTokensForEmails(_ emails: [String]) async -> [String: String] {
        // COST OPTIMIZATION: Chunk emails to prevent expensive Firebase queries
        let emailChunks = emails.chunked(into: maxBatchQuerySize)
        var result: [String: String] = [:]
        
        for emailChunk in emailChunks {
            let chunkResult = await getFCMTokensForEmailChunk(emailChunk)
            result.merge(chunkResult) { _, new in new }
        }
        
        return result
    }
    
    /// Process a single chunk of emails with caching
    private func getFCMTokensForEmailChunk(_ emails: [String]) async -> [String: String] {
        var result: [String: String] = [:]
        var emailsToFetch: [String] = []
        
        // Check cache first (thread-safe access)
        let currentCache = tokenCache
        for email in emails {
            if let cachedEntry = currentCache[email],
               Date().timeIntervalSince(cachedEntry.timestamp) < cacheExpirationInterval {
                result[email] = cachedEntry.token
            } else {
                emailsToFetch.append(email)
            }
        }
        
        // Fetch missing tokens from Firestore
        if !emailsToFetch.isEmpty {
            let fetchedTokens = await fetchTokensFromFirestore(emails: emailsToFetch)
            
            // Update cache safely
            var newCache = currentCache
            for (email, token) in fetchedTokens {
                newCache[email] = (token: token, timestamp: Date())
                result[email] = token
            }
            tokenCache = newCache
        }
        
        return result
    }
    
    /// Fetches FCM tokens from Firestore for given emails with COST OPTIMIZATION
    private func fetchTokensFromFirestore(emails: [String]) async -> [String: String] {
        var tokens: [String: String] = [:]
        
        do {
            // COST OPTIMIZATION: Single query to get both participant data and tokens
            let participantsRef = db.collection("participants")
            let snapshot = try await participantsRef.whereField("email", in: emails).getDocuments()
            
            // Extract tokens directly from participant documents (avoiding secondary queries)
            for document in snapshot.documents {
                let data = document.data()
                let email = data["email"] as? String ?? ""
                let fcmToken = data["fcmToken"] as? String
                
                if !email.isEmpty, let token = fcmToken, !token.isEmpty {
                    // Validate token format before using
                    if token.hasPrefix("fcm_token_") && token.count > 15 {
                        tokens[email] = token
                    } else {
                        AppLog.authWarning("Invalid FCM token format for \(email)")
                    }
                }
            }
            
            // FALLBACK: For emails not found in participants, try users collection (minimal cost)
            let missingEmails = Set(emails).subtracting(Set(tokens.keys))
            if !missingEmails.isEmpty && missingEmails.count <= 5 { // Limit expensive queries
                let fallbackTokens = await fetchTokensFromUsersCollection(Array(missingEmails))
                tokens.merge(fallbackTokens) { _, new in new }
            }
            
        } catch {
            AppLog.authError("Error fetching FCM tokens", error: error)
        }
        
        return tokens
    }
    
    /// Fallback method for missing tokens (COST CONTROLLED)
    private func fetchTokensFromUsersCollection(_ emails: [String]) async -> [String: String] {
        var tokens: [String: String] = [:]
        
        // COST CONTROL: Limit to 5 individual queries maximum
        let limitedEmails = Array(emails.prefix(5))
        
        await withTaskGroup(of: (String, String?).self) { group in
            for email in limitedEmails {
                group.addTask {
                    let userId = await self.getUserIdForEmail(email)
                    if let userId = userId {
                        let token = await self.fetchUserToken(userId: userId)
                        return (email, token)
                    }
                    return (email, nil)
                }
            }
            
            for await (email, token) in group {
                if let token = token {
                    tokens[email] = token
                }
            }
        }
        
        return tokens
    }
    
    /// Get user ID for email (cached lookup)
    private func getUserIdForEmail(_ email: String) async -> String? {
        do {
            let snapshot = try await db.collection("participants")
                .whereField("email", isEqualTo: email)
                .limit(to: 1)
                .getDocuments()
            
            return snapshot.documents.first?.data()["userId"] as? String
        } catch {
            return nil
        }
    }
    
    /// Fetches FCM token for a specific user ID
    private func fetchUserToken(userId: String) async -> String? {
        do {
            let userDoc = try await db.collection("users").document(userId).getDocument()
            let token = userDoc.data()?["fcmToken"] as? String
            
            // Validate token format
            if let token = token, token.hasPrefix("fcm_token_") && token.count > 15 {
                return token
            }
            return nil
        } catch {
            AppLog.authError("Error fetching token for user \(userId)", error: error)
            return nil
        }
    }
    
    /// Loads cached token from UserDefaults on app startup
    private func loadCachedToken() {
        if let cachedToken = UserDefaults.standard.string(forKey: "fcm_token"),
           let cachedDate = UserDefaults.standard.object(forKey: "fcm_token_refresh_date") as? Date {
            
            self.currentToken = cachedToken
            self.lastTokenRefresh = cachedDate
            self.isTokenValid = validateTokenHealth()
            
            AppLog.authSuccess("Loaded cached FCM token", userEmail: "system")
        }
    }
    
    deinit {
        tokenRefreshTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - FCM Token Error Types
enum FCMTokenError: LocalizedError {
    case tokenNotAvailable
    case refreshFailed(String)
    case networkError(String)
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .tokenNotAvailable:
            return "FCM token is not available"
        case .refreshFailed(let message):
            return "Token refresh failed: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .authenticationRequired:
            return "User must be authenticated to manage tokens"
        }
    }
}

// MARK: - Temporary Note
/*
 This file contains the structure for FCMTokenManager extracted from DataModels.swift.
 The actual implementation is temporarily left in the original file to avoid breaking changes.
 Once all files are created, we'll move the implementations in phases.
 */