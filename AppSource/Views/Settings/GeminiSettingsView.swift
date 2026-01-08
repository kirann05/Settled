//
//  GeminiSettingsView.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import SwiftUI

/// Settings view for managing Gemini API key for enhanced receipt classification
struct GeminiSettingsView: View {
    @State private var apiKey: String = ""
    @State private var isAPIKeyStored: Bool = false
    @State private var showSuccess: Bool = false
    @State private var errorMessage: String?
    @State private var isLoading: Bool = false
    @State private var showDeleteConfirmation: Bool = false

    private let keyProvider = KeychainAPIKeyProvider()

    var body: some View {
        Form {
            // Status Section
            statusSection

            // API Key Input Section
            apiKeySection

            // Information Section
            infoSection

            // How to Get API Key Section
            howToSection

            // Danger Zone (Delete Key)
            if isAPIKeyStored {
                dangerZoneSection
            }
        }
        .navigationTitle("AI Classification")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkAPIKeyStatus()
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            HStack {
                Image(systemName: isAPIKeyStored ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(isAPIKeyStored ? .green : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text(isAPIKeyStored ? "API Key Configured" : "API Key Not Configured")
                        .font(.headline)

                    Text(isAPIKeyStored
                         ? "AI-powered classification is enabled"
                         : "Using heuristics-only classification")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - API Key Input Section

    private var apiKeySection: some View {
        Section {
            if isAPIKeyStored {
                // Show masked key when stored
                HStack {
                    Text("API Key")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("••••••••••••••••")
                        .foregroundColor(.secondary)
                }
            } else {
                // Show input field when not stored
                SecureField("Enter API Key (AIza...)", text: $apiKey)
                    .textContentType(.password)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
            }

            // Action Buttons
            if isAPIKeyStored {
                Button(role: .destructive, action: {
                    showDeleteConfirmation = true
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove API Key")
                    }
                }
            } else {
                Button(action: saveAPIKey) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        HStack {
                            Image(systemName: "key.fill")
                            Text("Save API Key")
                        }
                    }
                }
                .disabled(apiKey.isEmpty || isLoading)
            }

            // Success/Error Messages
            if showSuccess {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("API Key saved securely in Keychain")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            if let error = errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        } header: {
            Text("Gemini API Key")
        } footer: {
            if !isAPIKeyStored {
                Text("Your API key is stored securely in iOS Keychain and never leaves your device.")
                    .font(.caption)
            }
        }
    }

    // MARK: - Info Section

    private var infoSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                InfoRow(
                    icon: "brain.head.profile",
                    title: "AI-Powered Classification",
                    description: "Gemini AI helps classify ambiguous receipt items with higher accuracy."
                )

                Divider()

                InfoRow(
                    icon: "checkmark.shield.fill",
                    title: "Privacy First",
                    description: "Your API key is encrypted and stored locally. Receipt data is only sent to Google when needed."
                )

                Divider()

                InfoRow(
                    icon: "dollarsign.circle.fill",
                    title: "Cost-Effective",
                    description: "Most items are classified for free. AI is only used for 5-10% of items. Estimated cost: < $2/month."
                )

                Divider()

                InfoRow(
                    icon: "speedometer",
                    title: "Fast & Efficient",
                    description: "Classification completes in < 2 seconds with AI, < 0.5 seconds without."
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("What is this?")
        }
    }

    // MARK: - How To Section

    private var howToSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HowToStep(number: 1, text: "Visit Google AI Studio")
                HowToStep(number: 2, text: "Sign in with your Google account")
                HowToStep(number: 3, text: "Click 'Get API key' or 'Create API key'")
                HowToStep(number: 4, text: "Copy the key (starts with 'AIza...')")
                HowToStep(number: 5, text: "Paste it above and tap 'Save API Key'")
            }
            .padding(.vertical, 4)

            Link(destination: URL(string: "https://aistudio.google.com/app/apikey")!) {
                HStack {
                    Image(systemName: "link")
                    Text("Open Google AI Studio")
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                }
            }

            // Free Tier Info
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Free Tier Included")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("15 requests/minute, 1,500/day")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("How to Get API Key")
        }
    }

    // MARK: - Danger Zone Section

    private var dangerZoneSection: some View {
        Section {
            Button(role: .destructive, action: {
                showDeleteConfirmation = true
            }) {
                HStack {
                    Image(systemName: "trash.fill")
                    Text("Delete API Key")
                    Spacer()
                }
            }
        } header: {
            Text("Danger Zone")
        } footer: {
            Text("This will remove the API key from your device. Classification will continue using heuristics only.")
                .font(.caption)
        }
        .confirmationDialog(
            "Delete API Key?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                deleteAPIKey()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete your Gemini API key? You can always add it back later.")
        }
    }

    // MARK: - Actions

    private func checkAPIKeyStatus() {
        isAPIKeyStored = keyProvider.hasAPIKey()
    }

    private func saveAPIKey() {
        // Validate API key format
        guard apiKey.hasPrefix("AIza") && apiKey.count > 20 else {
            errorMessage = "Invalid API key format. Key should start with 'AIza'."
            return
        }

        isLoading = true
        errorMessage = nil
        showSuccess = false

        // Simulate async save (Keychain is actually sync, but we add delay for UX)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            do {
                try keyProvider.setAPIKey(apiKey)

                // Success
                isAPIKeyStored = true
                showSuccess = true
                errorMessage = nil
                apiKey = "" // Clear for security

                // Hide success message after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showSuccess = false
                }

            } catch {
                errorMessage = "Failed to save API key: \(error.localizedDescription)"
                showSuccess = false
            }

            isLoading = false
        }
    }

    private func deleteAPIKey() {
        do {
            try keyProvider.deleteAPIKey()
            isAPIKeyStored = false
            apiKey = ""
            showSuccess = false
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete API key: \(error.localizedDescription)"
        }
    }
}

// MARK: - Supporting Views

struct InfoRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct HowToStep: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 24, height: 24)

                Text("\(number)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            Text(text)
                .font(.subheadline)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        GeminiSettingsView()
    }
}
