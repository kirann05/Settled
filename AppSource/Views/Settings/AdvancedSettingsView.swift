//
//  AdvancedSettingsView.swift
//  Settled
//
//  Created by Claude on 2025-10-26.
//

import SwiftUI

/// Advanced settings for power users
struct AdvancedSettingsView: View {
    @State private var classificationConfig: ClassificationConfigOption = .default

    var body: some View {
        Form {
            // Gemini API Configuration
            Section {
                NavigationLink(destination: GeminiSettingsView()) {
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                            .frame(width: 30)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("AI Classification")
                                .font(.body)

                            Text("Configure Gemini API for enhanced accuracy")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                }
            }

            // Classification Mode
            Section {
                Picker("Mode", selection: $classificationConfig) {
                    ForEach(ClassificationConfigOption.allCases, id: \.self) { option in
                        Text(option.displayName).tag(option)
                    }
                }
                .pickerStyle(.menu)

                // Mode Description
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: classificationConfig.icon)
                            .foregroundColor(classificationConfig.color)
                        Text(classificationConfig.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }

                    Text(classificationConfig.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Classification Mode")
            } footer: {
                Text("Changes will take effect on the next receipt scan.")
                    .font(.caption)
            }

            // Statistics (Future)
            Section {
                HStack {
                    Text("Receipts Classified")
                    Spacer()
                    Text("N/A")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Average Confidence")
                    Spacer()
                    Text("N/A")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Manual Corrections")
                    Spacer()
                    Text("N/A")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("Statistics")
            }

            // About
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Classification System")
                    Spacer()
                    Text("v2.0")
                        .foregroundColor(.secondary)
                }
            } header: {
                Text("About")
            }
        }
        .navigationTitle("Advanced Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSavedConfig()
        }
        .onChange(of: classificationConfig) { _, newValue in
            saveConfig(newValue)
        }
    }

    // MARK: - Helpers

    private func loadSavedConfig() {
        if let savedConfig = UserDefaults.standard.string(forKey: "ClassificationConfig"),
           let config = ClassificationConfigOption(rawValue: savedConfig) {
            classificationConfig = config
        }
    }

    private func saveConfig(_ config: ClassificationConfigOption) {
        UserDefaults.standard.set(config.rawValue, forKey: "ClassificationConfig")
    }
}

// MARK: - Classification Config Options

enum ClassificationConfigOption: String, CaseIterable {
    case conservative
    case `default`
    case aggressive

    var displayName: String {
        switch self {
        case .conservative: return "Conservative (No AI)"
        case .default: return "Balanced (Recommended)"
        case .aggressive: return "Aggressive (More AI)"
        }
    }

    var description: String {
        switch self {
        case .conservative:
            return "Uses only heuristics. Zero AI costs. Good accuracy (85-90%)."
        case .default:
            return "Uses AI for ambiguous items only. Best balance of accuracy and cost. (90-95% accuracy, ~$2/month)"
        case .aggressive:
            return "Uses AI more frequently for maximum accuracy. Higher costs. (95%+ accuracy, ~$5/month)"
        }
    }

    var icon: String {
        switch self {
        case .conservative: return "shield.fill"
        case .default: return "balance.scale.fill"
        case .aggressive: return "bolt.fill"
        }
    }

    var color: Color {
        switch self {
        case .conservative: return .green
        case .default: return .blue
        case .aggressive: return .orange
        }
    }

    var config: ClassificationConfig {
        switch self {
        case .conservative: return .conservative
        case .default: return .default
        case .aggressive: return .aggressive
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        AdvancedSettingsView()
    }
}
