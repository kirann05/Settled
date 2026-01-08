import Foundation
import os.log

// MARK: - Settled App Logging System
// Industry-standard unified logging using OSLog with domain-based categories
// Follows Apple guidelines for production logging with privacy compliance

extension OSLog {
    // MARK: - Core Business Domains
    
    /// Authentication operations (login, logout, user validation)
    static let authentication = OSLog(
        subsystem: "com.settled.core", 
        category: "authentication"
    )
    
    /// Bill management (CRUD operations, calculations, splitting logic)
    static let billManagement = OSLog(
        subsystem: "com.settled.core", 
        category: "bill-management"
    )
    
    /// Firebase operations (Firestore, Auth, Cloud Functions)
    static let firebase = OSLog(
        subsystem: "com.settled.core", 
        category: "firebase"
    )
    
    /// Push notifications (FCM, APNS, token management)
    static let pushNotifications = OSLog(
        subsystem: "com.settled.core", 
        category: "push-notifications"
    )
    
    /// Data synchronization and real-time updates
    static let dataSync = OSLog(
        subsystem: "com.settled.core", 
        category: "data-sync"
    )
    
    /// Contact management and user interactions
    static let contacts = OSLog(
        subsystem: "com.settled.core", 
        category: "contacts"
    )
    
    /// Financial calculations and currency operations
    static let calculations = OSLog(
        subsystem: "com.settled.core", 
        category: "calculations"
    )
    
    // MARK: - User Interface & Experience
    
    /// UI interactions, navigation, user experience events
    static let userInterface = OSLog(
        subsystem: "com.settled.ui", 
        category: "user-interface"
    )
    
    /// OCR and receipt processing
    static let ocr = OSLog(
        subsystem: "com.settled.features", 
        category: "ocr"
    )
    
    /// Session management and app state
    static let session = OSLog(
        subsystem: "com.settled.core", 
        category: "session"
    )
    
    // MARK: - Development & Debugging
    
    /// General app lifecycle and configuration
    static let app = OSLog(
        subsystem: "com.settled.core", 
        category: "app-lifecycle"
    )
}

// MARK: - Logging Convenience Functions
// Provides easy-to-use logging functions with proper privacy handling

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
    
    static func firebaseSuccess(_ message: String) {
        os_log("✅ Firebase: %{public}@", log: .firebase, type: .info, message)
    }
    
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
            // Only log first 8 characters of token for privacy
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
    
    // MARK: - General Application Logging
    
    static func appEvent(_ message: String) {
        os_log("🔗 %{public}@", log: .app, type: .info, message)
    }
    
    static func appError(_ message: String, error: Error? = nil) {
        if let error = error {
            os_log("❌ App: %{public}@: %{public}@", log: .app, type: .error, message, error.localizedDescription)
        } else {
            os_log("❌ App: %{public}@", log: .app, type: .error, message)
        }
    }
    
    // MARK: - Debug Logging (Development Only)
    
    static func debug(_ message: String, category: OSLog = .app) {
        #if DEBUG
        os_log("🔍 DEBUG: %{public}@", log: category, type: .debug, message)
        #endif
    }
}

// MARK: - Development Debug Helpers
// Conditional compilation ensures zero production overhead

#if DEBUG
struct DevLog {
    /// Development-only console logging with immediate visibility
    /// These are completely removed from release builds
    
    static func trace(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
    }
    
    static func variable<T>(_ name: String, value: T, file: String = #file, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
    }
    
    static func step(_ step: String, details: String = "") {
        let suffix = details.isEmpty ? "" : " - \(details)"
    }
}
#endif

// MARK: - Migration Helper
// Temporary bridge to help migrate existing print statements

struct MigrationLog {
    /// Temporary helper for migrating print statements
    /// TODO: Remove after migration is complete
    
    static func migrate(_ originalPrint: String, to newLogging: String) {
        #if DEBUG
        #endif
    }
}