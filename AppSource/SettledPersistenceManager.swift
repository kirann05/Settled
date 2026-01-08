import Foundation

/// Manages filesystem persistence for BillSplitSession with 24-hour expiration
final class SettledPersistenceManager {
    static let shared = SettledPersistenceManager()

    private let fileManager = FileManager.default
    private let sessionExpirationInterval: TimeInterval = 24 * 60 * 60 // 24 hours

    private init() {}

    // MARK: - File Paths

    private var documentsDirectory: URL {
        return fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var sessionFileURL: URL {
        return documentsDirectory.appendingPathComponent("active_bill_session.json")
    }

    // MARK: - Save Session

    /// Saves session snapshot to disk with atomic write
    func saveSession(_ snapshot: BillSplitSessionSnapshot) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(snapshot)

            // Atomic write prevents corruption if interrupted
            try data.write(to: sessionFileURL, options: .atomic)


        } catch {
            throw SettledPersistenceError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Load Session

    /// Loads session from disk, returns nil if not found or expired
    func loadSession() -> BillSplitSessionSnapshot? {
        guard fileManager.fileExists(atPath: sessionFileURL.path) else {
            return nil
        }

        do {
            let data = try Data(contentsOf: sessionFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601

            let snapshot = try decoder.decode(BillSplitSessionSnapshot.self, from: data)

            // Check expiration
            let expirationDate = snapshot.lastSavedAt.addingTimeInterval(sessionExpirationInterval)
            if expirationDate < Date() {
                try? clearSession()
                return nil
            }


            return snapshot

        } catch DecodingError.dataCorrupted {
            try? clearSession()
            return nil
        } catch {
            try? clearSession()
            return nil
        }
    }

    // MARK: - Clear Session

    /// Deletes session file from disk
    func clearSession() throws {
        guard fileManager.fileExists(atPath: sessionFileURL.path) else {
            return
        }

        do {
            try fileManager.removeItem(at: sessionFileURL)
        } catch {
            throw SettledPersistenceError.clearFailed(error.localizedDescription)
        }
    }

    // MARK: - Session Info

    /// Quick check if session file exists (doesn't validate expiration)
    func hasActiveSession() -> Bool {
        guard fileManager.fileExists(atPath: sessionFileURL.path) else {
            return false
        }

        // Quick expiration check without full decode
        guard let attributes = try? fileManager.attributesOfItem(atPath: sessionFileURL.path),
              let modificationDate = attributes[.modificationDate] as? Date else {
            return false
        }

        let expirationDate = modificationDate.addingTimeInterval(sessionExpirationInterval)
        let isExpired = expirationDate < Date()

        if isExpired {
            try? clearSession()
            return false
        }

        return true
    }

    /// Returns session file size in bytes (for debugging)
    func sessionFileSize() -> Int64? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: sessionFileURL.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }

    /// Returns session file modification date (for debugging)
    func sessionFileModificationDate() -> Date? {
        guard let attributes = try? fileManager.attributesOfItem(atPath: sessionFileURL.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }
}

// MARK: - Error Types

enum SettledPersistenceError: LocalizedError {
    case saveFailed(String)
    case loadFailed(String)
    case clearFailed(String)
    case corruptedData

    var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            return "Failed to save session: \(reason)"
        case .loadFailed(let reason):
            return "Failed to load session: \(reason)"
        case .clearFailed(let reason):
            return "Failed to clear session: \(reason)"
        case .corruptedData:
            return "Session data is corrupted"
        }
    }
}
