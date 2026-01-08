//
//  DesignSystemPreview.swift
//  Settled Design System
//
//  Comprehensive demo showcasing all design system elements
//  Interactive preview with light/dark mode toggle and accessibility features
//

import SwiftUI

// MARK: - Main Design System Preview
struct DesignSystemPreview: View {
    @State private var colorScheme: ColorScheme = .light
    @State private var textSizeCategory: DynamicTypeSize = .large

    var body: some View {
        NavigationView {
            List {
                // Controls Section
                Section("Preview Controls") {
                    HStack {
                        Text("Color Scheme")
                            .font(.bodyText)
                            .foregroundColor(.adaptiveTextPrimary)
                        Spacer()
                        Picker("", selection: $colorScheme) {
                            Text("Light").tag(ColorScheme.light)
                            Text("Dark").tag(ColorScheme.dark)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 150)
                    }
                }

                // Foundation Section
                Section("Foundation") {
                    NavigationLink("Color System", destination: ColorSystemPreview())
                    NavigationLink("Typography Scale", destination: TypographyPreview())
                    NavigationLink("Spacing Scale", destination: SpacingPreview())
                    NavigationLink("Animations", destination: AnimationsPreview())
                }

                // Components Section
                Section("Components") {
                    NavigationLink("Buttons", destination: ButtonsPreview())
                    NavigationLink("Cards", destination: CardsPreview())
                    NavigationLink("Text Fields", destination: TextFieldsPreview())
                    NavigationLink("Toggles", destination: TogglesPreview())
                    NavigationLink("Modals", destination: ModalsPreview())
                    NavigationLink("Headers & Text", destination: HeadersPreview())
                    NavigationLink("List Rows", destination: ListRowsPreview())
                }

                // Accessibility Section
                Section("Accessibility") {
                    NavigationLink("Dynamic Type Demo", destination: DynamicTypePreview())
                    NavigationLink("Accessibility Features", destination: AccessibilityFeaturesPreview())
                }
            }
            .navigationTitle("Design System")
            .preferredColorScheme(colorScheme)
        }
    }
}

// MARK: - Color System Preview
struct ColorSystemPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingLG) {
                // Depth Levels
                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("Depth Levels")
                        .heading2()

                    Text("OKLCH-based perceptually uniform depth system")
                        .smallStyle()

                    // Depth 0
                    HStack {
                        Rectangle()
                            .fill(Color.adaptiveDepth0)
                            .frame(width: 60, height: 60)
                            .cornerRadius(.cornerRadiusSmall)

                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text("Depth 0")
                                .font(.h4)
                                .foregroundColor(.adaptiveTextPrimary)
                            Text("Base background")
                                .font(.smallText)
                                .foregroundColor(.adaptiveTextSecondary)
                        }
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth1)
                    .cornerRadius(.cornerRadiusMedium)

                    // Depth 1
                    HStack {
                        Rectangle()
                            .fill(Color.adaptiveDepth1)
                            .frame(width: 60, height: 60)
                            .cornerRadius(.cornerRadiusSmall)

                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text("Depth 1")
                                .font(.h4)
                                .foregroundColor(.adaptiveTextPrimary)
                            Text("Raised containers")
                                .font(.smallText)
                                .foregroundColor(.adaptiveTextSecondary)
                        }
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth0)
                    .cornerRadius(.cornerRadiusMedium)

                    // Depth 2
                    HStack {
                        Rectangle()
                            .fill(Color.adaptiveDepth2)
                            .frame(width: 60, height: 60)
                            .cornerRadius(.cornerRadiusSmall)

                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text("Depth 2")
                                .font(.h4)
                                .foregroundColor(.adaptiveTextPrimary)
                            Text("Card surfaces")
                                .font(.smallText)
                                .foregroundColor(.adaptiveTextSecondary)
                        }
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth0)
                    .cornerRadius(.cornerRadiusMedium)

                    // Depth 3
                    HStack {
                        Rectangle()
                            .fill(Color.adaptiveDepth3)
                            .frame(width: 60, height: 60)
                            .cornerRadius(.cornerRadiusSmall)

                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text("Depth 3")
                                .font(.h4)
                                .foregroundColor(.adaptiveTextPrimary)
                            Text("Elevated elements")
                                .font(.smallText)
                                .foregroundColor(.adaptiveTextSecondary)
                        }
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth0)
                    .cornerRadius(.cornerRadiusMedium)
                }

                // Text Hierarchy
                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("Text Hierarchy")
                        .heading2()

                    VStack(alignment: .leading, spacing: .spacingSM) {
                        Text("Primary Text (95% opacity)")
                            .font(.bodyText)
                            .foregroundColor(.adaptiveTextPrimary)

                        Text("Secondary Text (70% opacity)")
                            .font(.bodyText)
                            .foregroundColor(.adaptiveTextSecondary)

                        Text("Tertiary Text (50% opacity)")
                            .font(.bodyText)
                            .foregroundColor(.adaptiveTextTertiary)
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)
                }

                // Accent Color
                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("Accent Color")
                        .heading2()

                    HStack {
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: 80, height: 80)
                            .cornerRadius(.cornerRadiusMedium)

                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text("Accent Color")
                                .font(.h4)
                                .foregroundColor(.adaptiveTextPrimary)
                            Text("Use for primary actions, highlights, and interactive elements")
                                .font(.smallText)
                                .foregroundColor(.adaptiveTextSecondary)
                        }
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Color System")
    }
}

// MARK: - Typography Preview
struct TypographyPreview: View {
    @Environment(\.dynamicTypeSize) var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingLG) {
                Text("Type Scale with Dynamic Type")
                    .heading2()

                Text("Current text size: \(String(describing: dynamicTypeSize))")
                    .smallStyle()

                VStack(alignment: .leading, spacing: .spacingMD) {
                    // H1
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text("Heading 1")
                            .heading1()
                        Text(".heading1() • 40pt base • Dynamic Type enabled")
                            .captionStyle()
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)

                    // H2
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text("Heading 2")
                            .heading2()
                        Text(".heading2() • 32pt base • Dynamic Type enabled")
                            .captionStyle()
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)

                    // H3
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text("Heading 3")
                            .heading3()
                        Text(".heading3() • 24pt base • Dynamic Type enabled")
                            .captionStyle()
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)

                    // H4
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text("Heading 4")
                            .heading4()
                        Text(".heading4() • 20pt base • Dynamic Type enabled")
                            .captionStyle()
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)

                    // Body
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text("Body Text - Standard paragraph text for main content and descriptions")
                            .bodyStyle()
                        Text(".bodyStyle() • 16pt base • Dynamic Type enabled")
                            .captionStyle()
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)

                    // Small
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text("Small Text - Secondary content and metadata")
                            .smallStyle()
                        Text(".smallStyle() • 14pt base • Dynamic Type enabled")
                            .captionStyle()
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)

                    // Caption
                    VStack(alignment: .leading, spacing: .spacingXS) {
                        Text("Caption Text - Fine print, timestamps, and captions")
                            .captionStyle()
                        Text(".captionStyle() • 12pt base • Dynamic Type enabled")
                            .captionStyle()
                    }
                    .padding(.paddingCard)
                    .background(Color.adaptiveDepth2)
                    .cornerRadius(.cornerRadiusMedium)
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Typography")
    }
}

// MARK: - Spacing Preview
struct SpacingPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingLG) {
                Text("Spacing Scale")
                    .heading2()

                Text("4px/8px grid system for consistent layouts")
                    .smallStyle()

                VStack(alignment: .leading, spacing: .spacingMD) {
                    SpacingRow(name: "XS", value: .spacingXS, description: "4px - Tight spacing, icon padding")
                    SpacingRow(name: "SM", value: .spacingSM, description: "8px - Label-to-control, compact layouts")
                    SpacingRow(name: "MD", value: .spacingMD, description: "16px - Standard padding, element separation")
                    SpacingRow(name: "LG", value: .spacingLG, description: "24px - Section spacing, card padding")
                    SpacingRow(name: "XL", value: .spacingXL, description: "32px - Major section breaks, screen padding")
                    SpacingRow(name: "2XL", value: .spacing2XL, description: "48px - Large section separation")
                    SpacingRow(name: "3XL", value: .spacing3XL, description: "64px - Major visual breaks")
                }

                // Corner Radius
                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("Corner Radius")
                        .heading3()

                    HStack(spacing: .spacingMD) {
                        VStack {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 80, height: 80)
                                .cornerRadius(.cornerRadiusSmall)
                            Text("Small (8px)")
                                .captionStyle()
                        }

                        VStack {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 80, height: 80)
                                .cornerRadius(.cornerRadiusMedium)
                            Text("Medium (12px)")
                                .captionStyle()
                        }

                        VStack {
                            Rectangle()
                                .fill(Color.accentColor)
                                .frame(width: 80, height: 80)
                                .cornerRadius(.cornerRadiusLarge)
                            Text("Large (16px)")
                                .captionStyle()
                        }
                    }
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Spacing Scale")
    }
}

struct SpacingRow: View {
    let name: String
    let value: CGFloat
    let description: String

    var body: some View {
        HStack(spacing: .spacingMD) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: value, height: 40)

            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(name)
                    .font(.h4)
                    .foregroundColor(.adaptiveTextPrimary)
                Text(description)
                    .font(.smallText)
                    .foregroundColor(.adaptiveTextSecondary)
            }

            Spacer()
        }
        .padding(.paddingCard)
        .background(Color.adaptiveDepth2)
        .cornerRadius(.cornerRadiusMedium)
    }
}

// MARK: - Buttons Preview
struct ButtonsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLG) {
                Text("Button Styles")
                    .heading2()

                // Primary Button
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Button("Primary Button") {
                        print("Primary tapped")
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    Text("Use for: Main CTAs, important actions, form submissions")
                        .captionStyle()
                }

                // Secondary Button
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Button("Secondary Button") {
                        print("Secondary tapped")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("Use for: Secondary actions, cancel buttons, alternative choices")
                        .captionStyle()
                }

                // Tertiary Button
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Button("Tertiary Button") {
                        print("Tertiary tapped")
                    }
                    .buttonStyle(TertiaryButtonStyle())

                    Text("Use for: Tertiary actions, links, inline actions")
                        .captionStyle()
                }

                // Destructive Button
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Button("Delete Action") {
                        print("Delete tapped")
                    }
                    .buttonStyle(DestructiveButtonStyle())

                    Text("Use for: Delete actions, destructive confirmations")
                        .captionStyle()
                }

                // Full Width Example
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Button("Full Width Primary") {
                        print("Full width tapped")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)

                    Text("Full width button for forms and prominent actions")
                        .captionStyle()
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Buttons")
    }
}

// MARK: - Cards Preview
struct CardsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLG) {
                Text("Card Components")
                    .heading2()

                // Basic Card
                VStack(alignment: .leading, spacing: .spacingSM) {
                    CardView {
                        VStack(alignment: .leading, spacing: .spacingSM) {
                            Text("Basic Card")
                                .heading4()
                            Text("Standard card with consistent padding and shadow")
                                .bodyStyle()
                        }
                    }

                    Text("Use for: Content containers, list items, grouped content")
                        .captionStyle()
                }

                // Elevated Cards
                ForEach(1...3, id: \.self) { depth in
                    VStack(alignment: .leading, spacing: .spacingSM) {
                        ElevatedCard(depth: depth) {
                            VStack(alignment: .leading, spacing: .spacingSM) {
                                Text("Elevated Card - Depth \(depth)")
                                    .heading4()
                                Text("Hover to see elevation effect")
                                    .smallStyle()
                            }
                        }

                        Text("Depth \(depth) - \(depth == 1 ? "Subtle elevation" : depth == 2 ? "Standard elevation" : "High elevation")")
                            .captionStyle()
                    }
                }

                // Compact Card
                VStack(alignment: .leading, spacing: .spacingSM) {
                    CompactCard {
                        HStack {
                            Image(systemName: "star.fill")
                                .foregroundColor(.accentColor)
                            Text("Compact Card")
                                .bodyStyle()
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.adaptiveTextTertiary)
                        }
                    }

                    Text("Use for: List rows, compact displays, dense layouts")
                        .captionStyle()
                }

                // Interactive Card
                VStack(alignment: .leading, spacing: .spacingSM) {
                    InteractiveCard(action: { print("Card tapped") }) {
                        HStack {
                            VStack(alignment: .leading, spacing: .spacingSM) {
                                Text("Interactive Card")
                                    .heading4()
                                Text("Tap to see animation")
                                    .smallStyle()
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                        }
                    }

                    Text("Use for: Navigable cards, selectable items, interactive content")
                        .captionStyle()
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Cards")
    }
}

// MARK: - Text Fields Preview
struct TextFieldsPreview: View {
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var invalidEmail = "invalid"
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLG) {
                Text("Text Field Components")
                    .heading2()

                // Basic Text Field
                VStack(alignment: .leading, spacing: .spacingSM) {
                    StyledTextField(
                        label: "Username",
                        placeholder: "Enter your username",
                        text: $username
                    )
                    Text("Basic text field with label and focus state")
                        .captionStyle()
                }

                // Email Text Field
                VStack(alignment: .leading, spacing: .spacingSM) {
                    StyledTextField(
                        label: "Email Address",
                        placeholder: "you@example.com",
                        text: $email,
                        keyboardType: .emailAddress,
                        autocapitalization: .never
                    )
                    Text("Email-optimized keyboard with no autocapitalization")
                        .captionStyle()
                }

                // Secure Text Field
                VStack(alignment: .leading, spacing: .spacingSM) {
                    StyledTextField(
                        label: "Password",
                        placeholder: "Enter password",
                        text: $password,
                        isSecure: true
                    )
                    Text("Secure field for password entry")
                        .captionStyle()
                }

                // Text Field with Error
                VStack(alignment: .leading, spacing: .spacingSM) {
                    StyledTextFieldWithError(
                        label: "Email (with error)",
                        placeholder: "you@example.com",
                        text: $invalidEmail,
                        errorMessage: "Please enter a valid email address",
                        keyboardType: .emailAddress,
                        autocapitalization: .never
                    )
                    Text("Text field with validation error state")
                        .captionStyle()
                }

                // Search Field
                VStack(alignment: .leading, spacing: .spacingSM) {
                    SearchField(
                        placeholder: "Search for anything...",
                        text: $searchText
                    )
                    Text("Search-optimized field with clear button")
                        .captionStyle()
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Text Fields")
    }
}

// MARK: - Toggles Preview
struct TogglesPreview: View {
    @State private var toggle1 = true
    @State private var toggle2 = false
    @State private var toggle3 = true
    @State private var toggle4 = false
    @State private var toggle5 = true

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLG) {
                Text("Toggle Components")
                    .heading2()

                // Styled Toggle
                VStack(alignment: .leading, spacing: .spacingSM) {
                    StyledToggle(
                        label: "Enable Notifications",
                        isOn: $toggle1,
                        description: "Receive push notifications for bill updates"
                    )
                    Text("Standard toggle with label and description")
                        .captionStyle()
                }

                // Compact Toggle
                VStack(alignment: .leading, spacing: .spacingSM) {
                    CompactToggle(
                        label: "Dark Mode",
                        isOn: $toggle2
                    )
                    Text("Minimal toggle without background")
                        .captionStyle()
                }

                // Icon Toggle
                VStack(alignment: .leading, spacing: .spacingSM) {
                    IconToggle(
                        label: "Push Notifications",
                        icon: "bell.fill",
                        isOn: $toggle3,
                        iconColor: .accentColor
                    )
                    Text("Toggle with leading icon for visual emphasis")
                        .captionStyle()
                }

                // Card Toggle
                VStack(alignment: .leading, spacing: .spacingSM) {
                    CardToggle(
                        title: "Premium Features",
                        description: "Enable advanced bill splitting with custom rules and automatic calculations",
                        isOn: $toggle4,
                        icon: "star.fill"
                    )
                    Text("Elevated toggle card for important settings")
                        .captionStyle()
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Toggles")
    }
}

// MARK: - Modals Preview
struct ModalsPreview: View {
    @State private var showModal = false
    @State private var showBottomSheet = false
    @State private var showConfirmation = false
    @State private var showLoading = false

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: .spacingLG) {
                    Text("Modal Components")
                        .heading2()

                    // Standard Modal
                    VStack(alignment: .leading, spacing: .spacingSM) {
                        Button("Show Standard Modal") {
                            showModal = true
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        Text("Standard modal with overlay and smooth animations")
                            .captionStyle()
                    }

                    // Bottom Sheet
                    VStack(alignment: .leading, spacing: .spacingSM) {
                        Button("Show Bottom Sheet") {
                            showBottomSheet = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        Text("Bottom sheet that slides up from bottom")
                            .captionStyle()
                    }

                    // Confirmation Dialog
                    VStack(alignment: .leading, spacing: .spacingSM) {
                        Button("Show Confirmation") {
                            showConfirmation = true
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        Text("Confirmation dialog with destructive action")
                            .captionStyle()
                    }

                    // Loading Modal
                    VStack(alignment: .leading, spacing: .spacingSM) {
                        Button("Show Loading") {
                            showLoading = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                showLoading = false
                            }
                        }
                        .buttonStyle(TertiaryButtonStyle())
                        .frame(maxWidth: .infinity)

                        Text("Loading overlay (auto-dismisses after 2 seconds)")
                            .captionStyle()
                    }
                }
                .padding(.paddingScreen)
            }
            .background(Color.adaptiveDepth0)
            .navigationTitle("Modals")

            // Modal Overlays
            CustomModal(isPresented: $showModal) {
                VStack(spacing: .spacingLG) {
                    Text("Modal Title")
                        .heading2()

                    Text("This is a custom modal with overlay and smooth animations. Tap outside or the close button to dismiss.")
                        .bodyStyle()

                    Button("Confirm") {
                        showModal = false
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                }
            }

            BottomSheet(isPresented: $showBottomSheet) {
                VStack(spacing: .spacingLG) {
                    Text("Bottom Sheet")
                        .heading3()

                    VStack(spacing: .spacingMD) {
                        Button("Option 1") { showBottomSheet = false }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(maxWidth: .infinity)

                        Button("Option 2") { showBottomSheet = false }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(maxWidth: .infinity)
                    }
                }
            }

            ConfirmationDialog(
                isPresented: $showConfirmation,
                title: "Delete Bill?",
                message: "Are you sure you want to delete this bill? This action cannot be undone.",
                confirmTitle: "Delete",
                confirmAction: {
                    print("Bill deleted")
                },
                isDestructive: true
            )

            LoadingModal(
                isPresented: $showLoading,
                message: "Processing..."
            )
        }
    }
}

// MARK: - Headers Preview
struct HeadersPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLG) {
                Text("Headers & Text Components")
                    .heading2()

                // Heading Text
                VStack(alignment: .leading, spacing: .spacingSM) {
                    HeadingText("Main Screen Title")
                    Text("HeadingText component for screen titles")
                        .captionStyle()
                }

                // Body Text
                VStack(alignment: .leading, spacing: .spacingSM) {
                    BodyText("This is standard body text for main content and descriptions. It uses the body style with proper line spacing and readability.")
                    Text("BodyText component for content paragraphs")
                        .captionStyle()
                }

                // Section Header
                VStack(alignment: .leading, spacing: .spacingSM) {
                    SectionHeader(title: "Recent Activity")
                    Text("SectionHeader component for list sections")
                        .captionStyle()
                }

                // Section Header with Action
                VStack(alignment: .leading, spacing: .spacingSM) {
                    SectionHeader(
                        title: "Recent Bills",
                        actionTitle: "View All",
                        action: { print("View All tapped") }
                    )
                    Text("SectionHeader with action button")
                        .captionStyle()
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Headers & Text")
    }
}

// MARK: - List Rows Preview
struct ListRowsPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLG) {
                Text("List Row Components")
                    .heading2()

                // Standard List Row
                VStack(alignment: .leading, spacing: .spacingSM) {
                    StandardListRow(
                        title: "Standard List Row",
                        subtitle: "With subtitle and chevron",
                        systemIcon: "person.circle.fill"
                    )
                    Text("Basic list row with icon, text, and chevron")
                        .captionStyle()
                }

                // List Row with Badge
                VStack(alignment: .leading, spacing: .spacingSM) {
                    BadgeListRow(
                        title: "Notifications",
                        subtitle: "3 new messages",
                        systemIcon: "bell.fill",
                        badgeCount: 3
                    )
                    Text("List row with notification badge")
                        .captionStyle()
                }

                // List Row with Toggle
                VStack(alignment: .leading, spacing: .spacingSM) {
                    ToggleListRow(
                        title: "Push Notifications",
                        subtitle: "Receive real-time updates",
                        systemIcon: "bell.badge.fill",
                        isOn: .constant(true)
                    )
                    Text("List row with embedded toggle")
                        .captionStyle()
                }

                // Action List Row
                VStack(alignment: .leading, spacing: .spacingSM) {
                    ActionListRow(
                        title: "Delete Account",
                        subtitle: "Permanently remove your data",
                        systemIcon: "trash.fill",
                        isDestructive: true,
                        action: { print("Delete tapped") }
                    )
                    Text("Actionable list row with destructive style")
                        .captionStyle()
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("List Rows")
    }
}

// MARK: - Animations Preview
struct AnimationsPreview: View {
    @State private var isAnimated1 = false
    @State private var isAnimated2 = false
    @State private var isAnimated3 = false
    @State private var isAnimated4 = false
    @State private var isAnimated5 = false

    var body: some View {
        ScrollView {
            VStack(spacing: .spacingLG) {
                Text("Animation Styles")
                    .heading2()

                // Smooth Spring
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Button("Smooth Spring") {
                        withAnimation(.smoothSpring) {
                            isAnimated1.toggle()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .scaleEffect(isAnimated1 ? 1.1 : 1.0)

                    Text("Response: 0.3s, Damping: 0.7 - Quick and controlled")
                        .captionStyle()
                }

                // Gentle Spring
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 60, height: 60)
                        .offset(x: isAnimated2 ? 100 : 0)
                        .animation(.gentleSpring, value: isAnimated2)

                    Button("Gentle Spring") {
                        isAnimated2.toggle()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("Response: 0.4s, Damping: 0.8 - Soft and natural")
                        .captionStyle()
                }

                // Bouncy Spring
                VStack(alignment: .leading, spacing: .spacingSM) {
                    RoundedRectangle(cornerRadius: .cornerRadiusMedium)
                        .fill(Color.adaptiveAccentGreen)
                        .frame(width: 80, height: 80)
                        .scaleEffect(isAnimated3 ? 1.2 : 1.0)
                        .animation(.bouncySpring, value: isAnimated3)

                    Button("Bouncy Spring") {
                        isAnimated3.toggle()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("Response: 0.5s, Damping: 0.6 - Playful bounce")
                        .captionStyle()
                }

                // Snappy Spring
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Rectangle()
                        .fill(Color.adaptiveAccentOrange)
                        .frame(width: isAnimated4 ? 200 : 80, height: 60)
                        .cornerRadius(.cornerRadiusSmall)
                        .animation(.snappySpring, value: isAnimated4)

                    Button("Snappy Spring") {
                        isAnimated4.toggle()
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("Response: 0.25s, Damping: 0.9 - Quick and precise")
                        .captionStyle()
                }

                // Button Press
                VStack(alignment: .leading, spacing: .spacingSM) {
                    Button("Button Press Animation") {
                        // Animation happens on press
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .scaleEffect(isAnimated5 ? 0.95 : 1.0)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                withAnimation(.buttonPress) {
                                    isAnimated5 = true
                                }
                            }
                            .onEnded { _ in
                                withAnimation(.buttonPress) {
                                    isAnimated5 = false
                                }
                            }
                    )

                    Text("Duration: 0.15s - Quick press feedback")
                        .captionStyle()
                }
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Animations")
    }
}

// MARK: - Dynamic Type Preview
struct DynamicTypePreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingLG) {
                Text("Dynamic Type Support")
                    .heading2()

                Text("All typography automatically scales with iOS accessibility text size settings. Go to Settings > Accessibility > Display & Text Size > Larger Text to test.")
                    .bodyStyle()

                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("Heading 1").heading1()
                    Text("Heading 2").heading2()
                    Text("Heading 3").heading3()
                    Text("Heading 4").heading4()
                    Text("Body Text").bodyStyle()
                    Text("Small Text").smallStyle()
                    Text("Caption Text").captionStyle()
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth2)
                .cornerRadius(.cornerRadiusMedium)
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Dynamic Type")
    }
}

// MARK: - Accessibility Features Preview
struct AccessibilityFeaturesPreview: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: .spacingLG) {
                Text("Accessibility Features")
                    .heading2()

                // WCAG Compliance
                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("WCAG AA Compliance")
                        .heading3()

                    Text("• Text contrast ratios meet WCAG AA standards (4.5:1 for body text)")
                        .bodyStyle()
                    Text("• All interactive elements have minimum 44x44pt touch targets")
                        .bodyStyle()
                    Text("• Focus states clearly indicate keyboard navigation")
                        .bodyStyle()
                    Text("• Color is not the only means of conveying information")
                        .bodyStyle()
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth2)
                .cornerRadius(.cornerRadiusMedium)

                // VoiceOver Support
                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("VoiceOver Support")
                        .heading3()

                    Text("• All components have descriptive accessibility labels")
                        .bodyStyle()
                    Text("• Interactive elements provide accessibility hints")
                        .bodyStyle()
                    Text("• Complex views use proper accessibility grouping")
                        .bodyStyle()
                    Text("• Dynamic content changes are announced")
                        .bodyStyle()
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth2)
                .cornerRadius(.cornerRadiusMedium)

                // Dynamic Type
                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("Dynamic Type")
                        .heading3()

                    Text("• All text scales with user preferences")
                        .bodyStyle()
                    Text("• Layouts adapt to larger text sizes")
                        .bodyStyle()
                    Text("• Maintains readability at all sizes")
                        .bodyStyle()
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth2)
                .cornerRadius(.cornerRadiusMedium)

                // Reduced Motion
                VStack(alignment: .leading, spacing: .spacingMD) {
                    Text("Reduced Motion")
                        .heading3()

                    Text("• Animations respect reduced motion settings")
                        .bodyStyle()
                    Text("• Essential feedback preserved without motion")
                        .bodyStyle()
                    Text("• Alternative indicators for state changes")
                        .bodyStyle()
                }
                .padding(.paddingCard)
                .background(Color.adaptiveDepth2)
                .cornerRadius(.cornerRadiusMedium)
            }
            .padding(.paddingScreen)
        }
        .background(Color.adaptiveDepth0)
        .navigationTitle("Accessibility")
    }
}

// MARK: - Preview Provider
struct DesignSystemPreview_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DesignSystemPreview()
                .previewDisplayName("Design System")

            ColorSystemPreview()
                .previewDisplayName("Colors")

            ButtonsPreview()
                .previewDisplayName("Buttons")
        }
    }
}
