import Foundation
import FirebaseFirestore
import Combine

// MARK: - Push Notification Service with Epic 2 Implementation

final class PushNotificationService: ObservableObject {
    private let db = Firestore.firestore()
    
    // Retry configuration for Epic 2 requirements with SOLOPRENEUR OPTIMIZATION
    private let maxRetryAttempts = 5
    private let baseRetryInterval: TimeInterval = 2.0 // 2s, 4s, 8s, 16s, 32s
    private let batchSize = 10 // Process 10 participants per batch for large groups
    private let batchDelay: TimeInterval = 3.0 // 3-second delay between batches
    
    // MEMORY LEAK PREVENTION: Queue size limits for cost control
    private let maxQueueSize = 200 // Prevent unlimited growth
    private let queueCleanupThreshold = 150 // Start cleanup at 75% capacity
    private let maxNotificationAge: TimeInterval = 24 * 60 * 60 // 24 hours max retention
    
    // Retry queue for failed notifications with memory management
    @Published var pendingNotifications: [PendingNotification] = []
    @Published var notificationMetrics = NotificationMetrics()
    
    // SOLOPRENEUR COST CONTROL: Rate limiting to prevent Firebase cost spikes
    private let maxNotificationsPerMinute = 60
    private var notificationTimestamps: [Date] = []
    private let rateLimitQueue = DispatchQueue(label: "notification.ratelimit", qos: .utility)
    
    private var retryTimer: Timer?
    private var cleanupTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupRetryQueue()
        setupMemoryManagement()
    }
    
    // MARK: - Epic 2: Bill Operation Notifications with Rate Limiting
    
    /// US-SYNC-004: New Bill Creation Notifications
    func notifyBillCreated(bill: Bill, creatorName: String, excludeUserId: String) async {
        // RATE LIMITING: Check if we're within limits
        guard await checkRateLimit() else {
            AppLog.authWarning("Rate limit exceeded, queuing notification for later")
            await queueForLater(bill: bill, type: .created, actorName: creatorName, excludeUserId: excludeUserId)
            return
        }
        
        let notification = BillNotification(
            type: .created,
            billId: bill.id,
            billName: bill.displayName,
            actorName: creatorName,
            message: "\(bill.displayName) - Added by \(creatorName)",
            deepLink: "settled://bill/\(bill.id)"
        )
        
        let participantEmails = bill.participants
            .filter { $0.id != excludeUserId }
            .map { $0.email }
        
        await sendNotificationToParticipants(
            notification: notification,
            participantEmails: participantEmails
        )
        
        await MainActor.run {
            notificationMetrics.totalSent += participantEmails.count
            notificationMetrics.createdNotifications += 1
        }
    }
    
    /// US-SYNC-005: Bill Edit Notifications with Retry Queue
    func notifyBillEdited(bill: Bill, editorName: String, excludeUserId: String) async {
        guard await checkRateLimit() else {
            await queueForLater(bill: bill, type: .edited, actorName: editorName, excludeUserId: excludeUserId)
            return
        }
        
        let notification = BillNotification(
            type: .edited,
            billId: bill.id,
            billName: bill.displayName,
            actorName: editorName,
            message: "\(bill.displayName) - Edited by \(editorName)",
            deepLink: "settled://bill/\(bill.id)"
        )
        
        let participantEmails = bill.participants
            .filter { $0.id != excludeUserId }
            .map { $0.email }
        
        await sendNotificationToParticipants(
            notification: notification,
            participantEmails: participantEmails
        )
        
        await MainActor.run {
            notificationMetrics.totalSent += participantEmails.count
            notificationMetrics.editedNotifications += 1
        }
    }
    
    /// US-SYNC-006: Bill Deletion Notifications
    func notifyBillDeleted(bill: Bill, deleterName: String, excludeUserId: String) async {
        guard await checkRateLimit() else {
            await queueForLater(bill: bill, type: .deleted, actorName: deleterName, excludeUserId: excludeUserId)
            return
        }
        
        let notification = BillNotification(
            type: .deleted,
            billId: bill.id,
            billName: bill.displayName,
            actorName: deleterName,
            message: "\(bill.displayName) - Deleted by \(deleterName)",
            deepLink: "settled://home"
        )
        
        let participantEmails = bill.participants
            .filter { $0.id != excludeUserId }
            .map { $0.email }
        
        await sendNotificationToParticipants(
            notification: notification,
            participantEmails: participantEmails
        )
        
        await MainActor.run {
            notificationMetrics.totalSent += participantEmails.count
            notificationMetrics.deletedNotifications += 1
        }
    }
    
    // MARK: - Rate Limiting for Cost Control
    
    /// Check if we're within rate limits (solopreneur cost protection)
    private func checkRateLimit() async -> Bool {
        return await withCheckedContinuation { continuation in
            rateLimitQueue.async {
                let now = Date()
                let oneMinuteAgo = now.addingTimeInterval(-60)
                
                // Clean up old timestamps
                self.notificationTimestamps = self.notificationTimestamps.filter { $0 > oneMinuteAgo }
                
                // Check if we can send more notifications
                let canSend = self.notificationTimestamps.count < self.maxNotificationsPerMinute
                
                if canSend {
                    self.notificationTimestamps.append(now)
                }
                
                continuation.resume(returning: canSend)
            }
        }
    }
    
    /// Queue notification for later when rate limited
    private func queueForLater(bill: Bill, type: BillNotification.NotificationType, actorName: String, excludeUserId: String) async {
        let notification = BillNotification(
            type: type,
            billId: bill.id,
            billName: bill.displayName,
            actorName: actorName,
            message: "\(bill.displayName) - \(type.rawValue.capitalized) by \(actorName)",
            deepLink: type == .deleted ? "settled://home" : "settled://bill/\(bill.id)"
        )
        
        let participantEmails = bill.participants
            .filter { $0.id != excludeUserId }
            .map { $0.email }
        
        for email in participantEmails {
            let pendingNotification = PendingNotification(
                id: UUID().uuidString,
                notification: notification,
                token: "", // Will be resolved later
                participantEmail: email,
                attemptCount: 0,
                nextRetryAt: Date().addingTimeInterval(60), // Retry in 1 minute
                createdAt: Date()
            )
            
            await addToPendingQueue(pendingNotification)
        }
    }
    
    /// Queue batch of notifications for later processing (used by background task system)
    private func queueBatchForLater(notification: BillNotification, participantEmails: [String]) async {
        for email in participantEmails {
            let pendingNotification = PendingNotification(
                id: UUID().uuidString,
                notification: notification,
                token: "", // Will be resolved later
                participantEmail: email,
                attemptCount: 0,
                nextRetryAt: Date().addingTimeInterval(30), // Retry in 30 seconds (faster than rate-limited)
                createdAt: Date()
            )
            
            await addToPendingQueue(pendingNotification)
        }
    }
    
    // MARK: - US-SYNC-007: Batch Processing for Large Groups with Background Task Support
    
    private func sendNotificationToParticipants(notification: BillNotification, participantEmails: [String]) async {
        // For large groups (>10 participants), use batch processing
        if participantEmails.count > batchSize {
            await sendBatchedNotifications(notification: notification, participantEmails: participantEmails)
        } else {
            await sendSingleBatchNotification(notification: notification, participantEmails: participantEmails)
        }
    }
    
    /// US-SYNC-007: Batch notifications for large groups with background task support
    private func sendBatchedNotifications(notification: BillNotification, participantEmails: [String]) async {
        let batches = participantEmails.chunked(into: batchSize)
        
        // BACKGROUND TASK SUPPORT: Start background task for reliable delivery
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = await UIApplication.shared.beginBackgroundTask(withName: "BatchNotificationDelivery") {
            // Background task expired - clean up
            AppLog.authWarning("Background notification task expired")
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
        
        defer {
            // Always end background task when done
            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
        
        for (index, batch) in batches.enumerated() {
            // Check if background task is still valid
            guard backgroundTask != .invalid else {
                AppLog.authWarning("Background task invalid, queuing remaining notifications")
                // Queue remaining batches for later processing
                let remainingBatches = Array(batches[index...])
                for remainingBatch in remainingBatches {
                    await queueBatchForLater(notification: notification, participantEmails: remainingBatch)
                }
                break
            }
            
            // Add delay between batches (except first batch)
            if index > 0 {
                // Check remaining background time before delay
                let remainingTime = UIApplication.shared.backgroundTimeRemaining
                if remainingTime < 10.0 { // Less than 10 seconds remaining
                    AppLog.authWarning("Insufficient background time, queuing remaining batches")
                    let remainingBatches = Array(batches[index...])
                    for remainingBatch in remainingBatches {
                        await queueBatchForLater(notification: notification, participantEmails: remainingBatch)
                    }
                    break
                }
                
                try? await Task.sleep(nanoseconds: UInt64(batchDelay * 1_000_000_000))
            }
            
            await sendSingleBatchNotification(notification: notification, participantEmails: batch)
            
            await MainActor.run {
                notificationMetrics.batchesSent += 1
            }
        }
    }
    
    private func sendSingleBatchNotification(notification: BillNotification, participantEmails: [String]) async {
        do {
            // Get FCM tokens for participant emails
            let tokenMap = await FCMTokenManager.shared.getFCMTokensForEmails(participantEmails)
            
            // Send notifications to valid tokens
            for (email, token) in tokenMap {
                await sendNotificationWithRetry(
                    notification: notification,
                    token: token,
                    participantEmail: email
                )
            }
        } catch {
            AppLog.authError("Error sending batch notification", error: error)
            
            await MainActor.run {
                notificationMetrics.totalFailed += participantEmails.count
            }
        }
    }
    
    // MARK: - Memory-Safe Queue Management
    
    /// Add notification to pending queue with memory protection
    private func addToPendingQueue(_ notification: PendingNotification) async {
        await MainActor.run {
            // MEMORY LEAK FIX: Enforce queue size limits
            if self.pendingNotifications.count >= self.maxQueueSize {
                // Remove oldest notifications first
                let sortedByCreation = self.pendingNotifications.sorted { $0.createdAt < $1.createdAt }
                self.pendingNotifications = Array(sortedByCreation.suffix(self.maxQueueSize - 1))
                
                self.notificationMetrics.totalDropped += 1
                AppLog.authWarning("Notification queue full, dropped oldest notification")
            }
            
            self.pendingNotifications.append(notification)
        }
    }
    
    /// Sets up memory management and cleanup
    private func setupMemoryManagement() {
        // Clean up old notifications every 30 minutes
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            Task {
                await self?.cleanupOldNotifications()
            }
        }
    }
    
    /// Clean up old and expired notifications to prevent memory leaks
    private func cleanupOldNotifications() async {
        await MainActor.run {
            let now = Date()
            let initialCount = self.pendingNotifications.count
            
            // Remove notifications older than maxNotificationAge
            self.pendingNotifications = self.pendingNotifications.filter { notification in
                let age = now.timeIntervalSince(notification.createdAt)
                return age < self.maxNotificationAge
            }
            
            let removedCount = initialCount - self.pendingNotifications.count
            if removedCount > 0 {
                self.notificationMetrics.totalDropped += removedCount
                AppLog.authSuccess("Cleaned up \(removedCount) expired notifications", userEmail: "system")
            }
            
            // Proactive cleanup if queue is getting large
            if self.pendingNotifications.count > self.queueCleanupThreshold {
                // Keep only the most recent notifications
                let sortedByCreation = self.pendingNotifications.sorted { $0.createdAt > $1.createdAt }
                let keepCount = self.queueCleanupThreshold - 20 // Keep some buffer
                self.pendingNotifications = Array(sortedByCreation.prefix(keepCount))
                
                AppLog.authWarning("Proactive queue cleanup - keeping \(keepCount) most recent notifications")
            }
        }
    }
    
    // MARK: - Retry Logic with Exponential Backoff
    
    /// US-SYNC-005: Retry queue with exponential backoff (2s, 4s, 8s, 16s, 32s)
    private func sendNotificationWithRetry(notification: BillNotification, token: String, participantEmail: String) async {
        let pendingNotification = PendingNotification(
            id: UUID().uuidString,
            notification: notification,
            token: token,
            participantEmail: participantEmail,
            attemptCount: 0,
            nextRetryAt: Date(),
            createdAt: Date()
        )
        
        let success = await attemptNotificationDelivery(pendingNotification)
        
        if !success {
            await addToPendingQueue(pendingNotification)
        }
    }
    
    private func attemptNotificationDelivery(_ pendingNotification: PendingNotification) async -> Bool {
        do {
            // Simulate FCM API call (would use Firebase Cloud Functions or FCM API)
            let success = await sendFCMNotification(
                token: pendingNotification.token,
                title: "Settled",
                body: pendingNotification.notification.message,
                deepLink: pendingNotification.notification.deepLink,
                billId: pendingNotification.notification.billId
            )
            
            if success {
                await MainActor.run {
                    notificationMetrics.totalDelivered += 1
                }
                return true
            } else {
                throw NotificationError.deliveryFailed("FCM delivery failed")
            }
        } catch {
            AppLog.authError("Notification delivery failed for \(pendingNotification.participantEmail)", error: error)
            
            await MainActor.run {
                notificationMetrics.totalFailed += 1
            }
            return false
        }
    }
    
    /// Sets up retry queue processing
    private func setupRetryQueue() {
        // Process retry queue every 30 seconds
        retryTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.processRetryQueue()
            }
        }
    }
    
    /// Processes failed notifications with exponential backoff and memory management
    private func processRetryQueue() async {
        let now = Date()
        var notificationsToRetry: [PendingNotification] = []
        var notificationsToKeep: [PendingNotification] = []
        
        await MainActor.run {
            for notification in pendingNotifications {
                // Check age first - drop very old notifications
                let age = now.timeIntervalSince(notification.createdAt)
                if age > maxNotificationAge {
                    notificationMetrics.totalDropped += 1
                    continue
                }
                
                if notification.attemptCount >= maxRetryAttempts {
                    // Max retries reached, drop notification
                    notificationMetrics.totalDropped += 1
                } else if now >= notification.nextRetryAt {
                    // Ready for retry
                    notificationsToRetry.append(notification)
                } else {
                    // Still waiting for next retry
                    notificationsToKeep.append(notification)
                }
            }
            
            pendingNotifications = notificationsToKeep
        }
        
        // COST OPTIMIZATION: Process retries in smaller batches to avoid rate limits
        let retryBatches = notificationsToRetry.chunked(into: 5) // Small batches to control Firebase usage
        
        for batch in retryBatches {
            // Process batch with rate limiting
            for var notification in batch {
                guard await checkRateLimit() else {
                    // Rate limited, reschedule for later
                    notification.nextRetryAt = Date().addingTimeInterval(120) // Try again in 2 minutes
                    await addToPendingQueue(notification)
                    continue
                }
                
                let success = await attemptNotificationDelivery(notification)
                
                if !success && notification.attemptCount < maxRetryAttempts {
                    notification.attemptCount += 1
                    // Exponential backoff: 2s, 4s, 8s, 16s, 32s
                    let delaySeconds = baseRetryInterval * pow(2, Double(notification.attemptCount - 1))
                    notification.nextRetryAt = Date().addingTimeInterval(delaySeconds)
                    
                    await addToPendingQueue(notification)
                }
            }
            
            // Small delay between retry batches
            if retryBatches.count > 1 {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 second delay
            }
        }
    }
    
    // MARK: - FCM Integration
    
    /// Simulates sending FCM notification (would integrate with Firebase Cloud Functions)
    private func sendFCMNotification(token: String, title: String, body: String, deepLink: String, billId: String) async -> Bool {
        // This would typically call Firebase Cloud Functions or FCM REST API
        // For now, we'll simulate the API call
        
        do {
            // Simulate network delay and potential failures
            try await Task.sleep(nanoseconds: UInt64.random(in: 100_000_000...500_000_000)) // 0.1-0.5s delay
            
            // Simulate 95% success rate (5% failure for retry testing)
            let success = Int.random(in: 1...100) <= 95
            
            if success {
                AppLog.authSuccess("FCM notification sent to token \(String(token.prefix(10)))... - \(body)", userEmail: "system")
                return true
            } else {
                AppLog.authWarning("FCM notification failed for token \(String(token.prefix(10)))...")
                return false
            }
        } catch {
            return false
        }
    }
    
    /// US-SYNC-015: Deep linking support (will be used by UI)
    func handleNotificationTap(deepLink: String) {
        // This would be called by the app delegate or scene delegate
        // when user taps notification to navigate to specific bill
        AppLog.authSuccess("Handling deep link: \(deepLink)", userEmail: "system")
    }
    
    // MARK: - Metrics and Monitoring
    
    func getNotificationMetrics() -> NotificationMetrics {
        return notificationMetrics
    }
    
    /// Get current queue health metrics
    func getQueueHealth() -> (queueSize: Int, maxSize: Int, utilizationPercent: Int) {
        let queueSize = pendingNotifications.count
        let utilization = Int((Double(queueSize) / Double(maxQueueSize)) * 100)
        return (queueSize: queueSize, maxSize: maxQueueSize, utilizationPercent: utilization)
    }
    
    func resetMetrics() {
        notificationMetrics = NotificationMetrics()
    }
    
    /// Force cleanup for memory pressure situations
    func forceCleanup() async {
        await cleanupOldNotifications()
        
        // Additional aggressive cleanup if needed
        await MainActor.run {
            if self.pendingNotifications.count > self.maxQueueSize / 2 {
                // Keep only most recent notifications
                let sortedByTime = self.pendingNotifications.sorted { $0.createdAt > $1.createdAt }
                let keepCount = self.maxQueueSize / 4
                self.pendingNotifications = Array(sortedByTime.prefix(keepCount))
                AppLog.authWarning("Force cleanup - kept \(keepCount) most recent notifications")
            }
        }
    }
    
    // MARK: - Service Health & Monitoring

    /// Validates the complete push notification service health
    func validateServiceHealth() async -> Bool {
        AppLog.systemInfo("🔍 Validating Push Notification Service health...")

        var healthChecks: [String: Bool] = [:]

        // Check 1: Queue health
        let queueHealth = await checkQueueHealth()
        healthChecks["Queue Health"] = queueHealth

        // Check 2: Rate limiting system
        let rateLimitHealth = checkRateLimitingHealth()
        healthChecks["Rate Limiting"] = rateLimitHealth

        // Check 3: FCM Token Manager connectivity
        let tokenManagerHealth = FCMTokenManager.shared.validateTokenHealth()
        healthChecks["FCM Token Manager"] = tokenManagerHealth

        // Check 4: Memory management
        let memoryHealth = checkMemoryHealth()
        healthChecks["Memory Management"] = memoryHealth

        // Check 5: Background task capability
        let backgroundTaskHealth = checkBackgroundTaskHealth()
        healthChecks["Background Tasks"] = backgroundTaskHealth

        // Log results
        for (check, isHealthy) in healthChecks {
            let status = isHealthy ? "✅ Healthy" : "❌ Issue Detected"
            AppLog.systemInfo("   \(check): \(status)")
        }

        let overallHealth = !healthChecks.values.contains(false)
        let healthStatus = overallHealth ? "✅ Healthy" : "⚠️ Issues Detected"
        AppLog.systemInfo("🔍 Push Notification Service Overall Health: \(healthStatus)")

        return overallHealth
    }

    /// Check notification queue health
    private func checkQueueHealth() async -> Bool {
        return await withCheckedContinuation { continuation in
            notificationQueue.async {
                let queueCount = self.pendingNotifications.count
                let isHealthy = queueCount < self.maxQueueSize * 3/4 // 75% threshold

                if !isHealthy {
                    AppLog.systemWarning("Notification queue approaching capacity: \(queueCount)/\(self.maxQueueSize)")
                }

                continuation.resume(returning: isHealthy)
            }
        }
    }

    /// Check rate limiting system health
    private func checkRateLimitingHealth() -> Bool {
        return rateLimitQueue.sync {
            // Check if rate limiting is functioning
            let currentMinute = Int(Date().timeIntervalSince1970) / 60
            let currentCount = notificationCounts[currentMinute] ?? 0

            // Healthy if we're not at the limit
            let isHealthy = currentCount < maxNotificationsPerMinute

            if !isHealthy {
                AppLog.systemWarning("Rate limiting active: \(currentCount)/\(maxNotificationsPerMinute) notifications this minute")
            }

            return isHealthy
        }
    }

    /// Check memory management health
    private func checkMemoryHealth() -> Bool {
        let pendingCount = notificationQueue.sync { pendingNotifications.count }
        let retryCount = retryQueue.sync { retryNotifications.count }

        let totalMemoryUsage = pendingCount + retryCount
        let memoryThreshold = maxQueueSize + maxRetryQueueSize

        let isHealthy = totalMemoryUsage < memoryThreshold * 3/4 // 75% threshold

        if !isHealthy {
            AppLog.systemWarning("High memory usage in notification service: \(totalMemoryUsage) items")
        }

        return isHealthy
    }

    /// Check background task capability
    private func checkBackgroundTaskHealth() -> Bool {
        // Check if we can create background tasks
        let testTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "HealthCheck") {
            // Expiration handler
        }

        let isHealthy = testTaskIdentifier != .invalid

        if isHealthy {
            UIApplication.shared.endBackgroundTask(testTaskIdentifier)
        } else {
            AppLog.systemWarning("Background tasks not available - batch processing may be limited")
        }

        return isHealthy
    }

    deinit {
        retryTimer?.invalidate()
        cleanupTimer?.invalidate()
        cancellables.forEach { $0.cancel() }
    }
}

// MARK: - Data Models

struct BillNotification: Codable, Identifiable {
    let id = UUID()
    let type: NotificationType
    let billId: String
    let billName: String
    let actorName: String
    let message: String
    let deepLink: String
    let timestamp = Date()
    
    enum NotificationType: String, Codable {
        case created = "created"
        case edited = "edited"
        case deleted = "deleted"
    }
}


struct PendingNotification: Identifiable {
    let id: String
    let notification: BillNotification
    let token: String
    let participantEmail: String
    var attemptCount: Int
    var nextRetryAt: Date
    let createdAt: Date
}

struct NotificationMetrics: Codable {
    var totalSent: Int = 0
    var totalDelivered: Int = 0
    var totalFailed: Int = 0
    var totalDropped: Int = 0
    var createdNotifications: Int = 0
    var editedNotifications: Int = 0
    var deletedNotifications: Int = 0
    var batchesSent: Int = 0
    
    var successRate: Double {
        return totalSent > 0 ? Double(totalDelivered) / Double(totalSent) : 0.0
    }
    
    var failureRate: Double {
        return totalSent > 0 ? Double(totalFailed) / Double(totalSent) : 0.0
    }
}

enum NotificationError: LocalizedError {
    case deliveryFailed(String)
    case tokenNotFound
    case rateLimited
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .deliveryFailed(let message):
            return "Notification delivery failed: \(message)"
        case .tokenNotFound:
            return "FCM token not found for participant"
        case .rateLimited:
            return "FCM rate limit exceeded"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}

// MARK: - Array Extension for Batching

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}