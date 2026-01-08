//
//  StyledToggle.swift
//  Settled Design System
//
//  Reusable toggle with consistent styling and design system integration
//  Includes standard and card-style toggles
//

import SwiftUI

// MARK: - Styled Toggle
/// Toggle with label and consistent design system styling
/// Use for: Settings, preferences, feature flags, boolean options
struct StyledToggle: View {
    let label: String
    @Binding var isOn: Bool
    var description: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: .spacingMD) {
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(label)
                    .font(.cerealBody)
                    .foregroundColor(.adaptiveTextPrimary)

                if let description = description {
                    Text(description)
                        .font(.cerealCaption)
                        .foregroundColor(.adaptiveTextSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.spacingMD)
        .background(Color.adaptiveDepth1)
        .cornerRadius(.cornerRadiusSmall)
        .animation(.smoothSpring, value: isOn)
    }
}

// MARK: - Compact Toggle
/// Minimal toggle without background
/// Use for: Inline toggles, compact layouts, list items
struct CompactToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
                .font(.cerealBody)
                .foregroundColor(.adaptiveTextPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
        .animation(.smoothSpring, value: isOn)
    }
}

// MARK: - Toggle with Icon
/// Toggle with leading icon for visual emphasis
/// Use for: Feature toggles, visual settings, categorized options
struct IconToggle: View {
    let label: String
    let icon: String
    @Binding var isOn: Bool
    var iconColor: Color = .accentColor

    var body: some View {
        HStack(spacing: .spacingMD) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)
                .frame(width: 32, height: 32)

            Text(label)
                .font(.cerealBody)
                .foregroundColor(.adaptiveTextPrimary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.spacingMD)
        .background(Color.adaptiveDepth1)
        .cornerRadius(.cornerRadiusSmall)
        .animation(.smoothSpring, value: isOn)
    }
}

// MARK: - Card Toggle
/// Toggle in elevated card with more prominence
/// Use for: Important settings, premium features, highlighted options
struct CardToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool
    var icon: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: .spacingMD) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
            }

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(title)
                    .font(.cerealTitle3)
                    .foregroundColor(.adaptiveTextPrimary)

                Text(description)
                    .font(.cerealCaption)
                    .foregroundColor(.adaptiveTextSecondary)
                    .lineLimit(3)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(.accentColor)
        }
        .padding(.paddingCard)
        .background(Color.surfaceElevated)
        .cornerRadius(.cornerRadiusMedium)
        .shadow(color: Color.shadowMedium, radius: 8, x: 0, y: 4)
        .animation(Animation.spring(response: 0.3, dampingFraction: 0.7), value: isOn)
    }
}

// MARK: - Preview Provider
struct StyledToggle_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var notificationsEnabled = true
        @State private var darkModeEnabled = false
        @State private var biometricEnabled = true
        @State private var autoSplitEnabled = false
        @State private var pushEnabled = true
        @State private var emailEnabled = false

        var body: some View {
            ScrollView {
                VStack(spacing: .spacingLG) {
                    // Styled Toggle
                    StyledToggle(
                        label: "Enable Notifications",
                        isOn: $notificationsEnabled,
                        description: "Receive push notifications for bill updates"
                    )

                    // Styled Toggle without description
                    StyledToggle(
                        label: "Dark Mode",
                        isOn: $darkModeEnabled
                    )

                    // Compact Toggle
                    VStack(spacing: .spacingMD) {
                        CompactToggle(
                            label: "Auto-split bills",
                            isOn: $autoSplitEnabled
                        )

                        CompactToggle(
                            label: "Biometric authentication",
                            isOn: $biometricEnabled
                        )
                    }
                    .padding(.spacingMD)
                    .background(Color.adaptiveDepth1)
                    .cornerRadius(.cornerRadiusMedium)

                    // Icon Toggle
                    IconToggle(
                        label: "Push Notifications",
                        icon: "bell.fill",
                        isOn: $pushEnabled,
                        iconColor: .accentColor
                    )

                    IconToggle(
                        label: "Email Notifications",
                        icon: "envelope.fill",
                        isOn: $emailEnabled,
                        iconColor: .blue
                    )

                    // Card Toggle
                    CardToggle(
                        title: "Premium Features",
                        description: "Enable advanced bill splitting with custom rules and automatic calculations",
                        isOn: $autoSplitEnabled,
                        icon: "star.fill"
                    )
                }
                .padding(.paddingScreen)
            }
            .background(Color.adaptiveDepth0)
        }
    }

    static var previews: some View {
        Group {
            PreviewContainer()
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")

            PreviewContainer()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}

// MARK: - Accessibility
extension StyledToggle {
    /// Add accessibility label to toggle
    func accessibilityToggle(label: String, hint: String? = nil) -> some View {
        self.accessibilityElement(children: .combine)
            .accessibilityLabel(label)
            .accessibilityHint(hint ?? "Double tap to toggle")
    }
}

// MARK: - Usage Examples
/*

 Basic Toggle:
 ```
 @State private var notificationsEnabled = true

 StyledToggle(
     label: "Enable Notifications",
     isOn: $notificationsEnabled,
     description: "Receive updates about your bills"
 )
 ```

 Compact Toggle in List:
 ```
 @State private var darkMode = false

 List {
     CompactToggle(
         label: "Dark Mode",
         isOn: $darkMode
     )
 }
 ```

 Icon Toggle:
 ```
 @State private var faceIDEnabled = true

 IconToggle(
     label: "Face ID",
     icon: "faceid",
     isOn: $faceIDEnabled,
     iconColor: .green
 )
 ```

 Premium Feature Card:
 ```
 @State private var premiumEnabled = false

 CardToggle(
     title: "Premium Features",
     description: "Unlock advanced splitting and analytics",
     isOn: $premiumEnabled,
     icon: "star.fill"
 )
 ```

 Settings Screen:
 ```
 VStack(spacing: .spacingLG) {
     StyledToggle(
         label: "Push Notifications",
         isOn: $pushEnabled,
         description: "Get notified about bill updates"
     )

     StyledToggle(
         label: "Email Reminders",
         isOn: $emailEnabled,
         description: "Receive email reminders for pending bills"
     )

     StyledToggle(
         label: "Auto-split",
         isOn: $autoSplitEnabled,
         description: "Automatically split bills equally"
     )
 }
 ```

 */
