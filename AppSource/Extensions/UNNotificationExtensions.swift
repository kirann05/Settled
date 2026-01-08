import UserNotifications
import Foundation

// MARK: - UNAuthorizationStatus Extensions
public extension UNAuthorizationStatus {
    var description: String {
        switch self {
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral (App Clip)"
        @unknown default:
            return "Unknown (\(rawValue))"
        }
    }

    var isAuthorized: Bool {
        return self == .authorized || self == .provisional
    }
}

// MARK: - UNNotificationSetting Extensions
public extension UNNotificationSetting {
    var description: String {
        switch self {
        case .notSupported:
            return "Not Supported"
        case .disabled:
            return "Disabled"
        case .enabled:
            return "Enabled"
        @unknown default:
            return "Unknown (\(rawValue))"
        }
    }
}

// MARK: - UNAlertStyle Extensions
public extension UNAlertStyle {
    var description: String {
        switch self {
        case .none:
            return "None"
        case .banner:
            return "Banner"
        case .alert:
            return "Alert"
        @unknown default:
            return "Unknown (\(rawValue))"
        }
    }
}

// MARK: - UNShowPreviewsSetting Extensions
public extension UNShowPreviewsSetting {
    var description: String {
        switch self {
        case .always:
            return "Always"
        case .whenAuthenticated:
            return "When Authenticated"
        case .never:
            return "Never"
        @unknown default:
            return "Unknown (\(rawValue))"
        }
    }
}

// MARK: - UNNotificationSettings Extensions
public extension UNNotificationSettings {

    /// Comprehensive health check for notification settings
    var isOptimallyConfigured: Bool {
        return authorizationStatus.isAuthorized &&
               alertSetting == .enabled &&
               soundSetting == .enabled &&
               badgeSetting == .enabled &&
               notificationCenterSetting == .enabled &&
               lockScreenSetting == .enabled
    }

    /// Configuration issues that might affect notification delivery
    var configurationIssues: [String] {
        var issues: [String] = []

        if !authorizationStatus.isAuthorized {
            issues.append("Authorization not granted")
        }

        if alertSetting != .enabled {
            issues.append("Alerts disabled")
        }

        if soundSetting != .enabled {
            issues.append("Sound disabled")
        }

        if badgeSetting != .enabled {
            issues.append("Badge disabled")
        }

        if notificationCenterSetting != .enabled {
            issues.append("Notification Center disabled")
        }

        if lockScreenSetting != .enabled {
            issues.append("Lock Screen disabled")
        }

        return issues
    }

    /// Detailed configuration report
    var configurationReport: String {
        let issues = configurationIssues

        if issues.isEmpty {
            return "✅ All notification settings optimally configured"
        } else {
            let issueList = issues.map { "• \($0)" }.joined(separator: "\n")
            return "⚠️ Configuration Issues:\n\(issueList)"
        }
    }
}