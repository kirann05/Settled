//
//  ClassificationConfigManager.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import Foundation

/// Manages classification configuration across the app
class ClassificationConfigManager {
    static let shared = ClassificationConfigManager()

    private let userDefaultsKey = "ClassificationConfig"

    private init() {}

    /// Get the current classification configuration
    func getCurrentConfig() -> ClassificationConfig {
        let savedOption = UserDefaults.standard.string(forKey: userDefaultsKey) ?? "default"

        switch savedOption {
        case "conservative":
            return .conservative
        case "aggressive":
            return .aggressive
        default:
            return .default
        }
    }

    /// Save a new configuration
    func saveConfig(_ option: String) {
        UserDefaults.standard.set(option, forKey: userDefaultsKey)
    }

    /// Check if Gemini is enabled in current config
    func isGeminiEnabled() -> Bool {
        let config = getCurrentConfig()
        return config.enableGeminiClassification
    }

    /// Check if API key is available
    func hasAPIKey() -> Bool {
        let keyProvider = KeychainAPIKeyProvider()
        return keyProvider.hasAPIKey()
    }

    /// Get API key status for UI display
    func getAPIKeyStatus() -> APIKeyStatus {
        let hasKey = hasAPIKey()
        let isEnabled = isGeminiEnabled()

        if hasKey && isEnabled {
            return .active
        } else if hasKey && !isEnabled {
            return .configured
        } else if !hasKey && isEnabled {
            return .missing
        } else {
            return .disabled
        }
    }
}

// MARK: - API Key Status

enum APIKeyStatus {
    case active       // Key present and Gemini enabled
    case configured   // Key present but Gemini disabled
    case missing      // Gemini enabled but key missing
    case disabled     // Gemini disabled and no key

    var displayText: String {
        switch self {
        case .active: return "AI Classification Active"
        case .configured: return "API Key Configured"
        case .missing: return "API Key Required"
        case .disabled: return "AI Classification Disabled"
        }
    }

    var icon: String {
        switch self {
        case .active: return "checkmark.circle.fill"
        case .configured: return "key.fill"
        case .missing: return "exclamationmark.triangle.fill"
        case .disabled: return "xmark.circle"
        }
    }

    var color: String {
        switch self {
        case .active: return "green"
        case .configured: return "blue"
        case .missing: return "orange"
        case .disabled: return "gray"
        }
    }
}
