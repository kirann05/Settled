import Foundation
import SwiftUI

/// Orchestrates session recovery UI and user interaction
@MainActor
final class SettledRecoveryManager: ObservableObject {
    @Published var hasSavedSession: Bool = false
    @Published var savedSessionSnapshot: BillSplitSessionSnapshot?
    @Published var showRecoveryBanner: Bool = false
    @Published var isCheckingForSession: Bool = false

    init() {}

    // MARK: - Session Detection

    /// Checks for saved session on app launch or navigation to home
    func checkForSavedSession() {
        isCheckingForSession = true

        // Check if session exists and is valid
        let hasSession = SettledPersistenceManager.shared.hasActiveSession()

        if hasSession {
            // Load the full session data
            savedSessionSnapshot = SettledPersistenceManager.shared.loadSession()

            if let snapshot = savedSessionSnapshot {
                // Validate session is actually incomplete and has meaningful data
                // sessionState is stored as String (SessionState.rawValue)
                let isIncomplete = snapshot.sessionState != "complete" && snapshot.sessionState != "home"
                let hasMeaningfulData = !snapshot.assignedItems.isEmpty || !snapshot.participants.isEmpty

                if isIncomplete && hasMeaningfulData {
                    hasSavedSession = true
                    showRecoveryBanner = true
                } else {

                    // Clear invalid session automatically
                    do {
                        try SettledPersistenceManager.shared.clearSession()
                    } catch {
                    }

                    hasSavedSession = false
                    showRecoveryBanner = false
                }
            } else {
                hasSavedSession = false
                showRecoveryBanner = false
            }
        } else {
            hasSavedSession = false
            showRecoveryBanner = false
        }

        isCheckingForSession = false
    }

    // MARK: - User Actions

    /// User chose to restore the saved session
    func acceptRecovery() {
        showRecoveryBanner = false
        // ContentView will handle actual restoration using savedSessionSnapshot
    }

    /// User chose to discard the saved session and start fresh
    func discardRecovery() {

        do {
            try SettledPersistenceManager.shared.clearSession()
        } catch {
        }

        hasSavedSession = false
        savedSessionSnapshot = nil
        showRecoveryBanner = false
    }

    /// Resets recovery state after successful restoration
    func reset() {
        hasSavedSession = false
        savedSessionSnapshot = nil
        showRecoveryBanner = false
    }

    // MARK: - Debug Helpers

    /// Returns current session recovery state for debugging
    func debugInfo() -> String {
        return """
        SettledRecoveryManager State:
        - Has Saved Session: \(hasSavedSession)
        - Show Banner: \(showRecoveryBanner)
        - Snapshot Loaded: \(savedSessionSnapshot != nil)
        - Is Checking: \(isCheckingForSession)
        """
    }
}
