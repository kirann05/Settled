//
//  SectionHeader.swift
//  Settled Design System
//
//  Reusable section header with optional action button
//  Includes typography hierarchy and design system integration
//

import SwiftUI

// MARK: - Section Header
/// Section header with title and optional action button
/// Use for: Section titles, list headers, content organization
struct SectionHeader: View {
    let title: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.h3Dynamic)
                .foregroundColor(.adaptiveTextPrimary)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.cerealBody)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Section Header with Subtitle
/// Section header with title, subtitle, and optional action
/// Use for: Detailed sections, informational headers
struct SectionHeaderWithSubtitle: View {
    let title: String
    let subtitle: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        subtitle: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: .spacingXS) {
                Text(title)
                    .font(.h3Dynamic)
                    .foregroundColor(.adaptiveTextPrimary)

                Text(subtitle)
                    .font(.cerealCaption)
                    .foregroundColor(.adaptiveTextSecondary)
            }

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.cerealBody)
                        .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Section Header with Icon
/// Section header with leading icon
/// Use for: Categorized sections, visual emphasis
struct IconSectionHeader: View {
    let title: String
    let icon: String
    let iconColor: Color
    let actionTitle: String?
    let action: (() -> Void)?

    init(
        title: String,
        icon: String,
        iconColor: Color = .accentColor,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.icon = icon
        self.iconColor = iconColor
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .center, spacing: .spacingMD) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(iconColor)

            Text(title)
                .font(.h3Dynamic)
                .foregroundColor(.adaptiveTextPrimary)

            Spacer()

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    HStack(spacing: .spacingXS) {
                        Text(actionTitle)
                            .font(.cerealBody)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .foregroundColor(.accentColor)
                }
            }
        }
    }
}

// MARK: - Expandable Section Header
/// Section header with expand/collapse toggle
/// Use for: Collapsible sections, accordion menus
struct ExpandableSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool

    var body: some View {
        Button(action: { withAnimation(.smoothSpring) { isExpanded.toggle() } }) {
            HStack {
                Text(title)
                    .font(.h4Dynamic)
                    .foregroundColor(.adaptiveTextPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.body)
                    .foregroundColor(.adaptiveTextTertiary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .animation(.smoothSpring, value: isExpanded)
            }
            .padding(.spacingMD)
            .background(Color.adaptiveDepth1)
            .cornerRadius(.cornerRadiusSmall)
        }
    }
}

// MARK: - Preview Provider
struct SectionHeader_Previews: PreviewProvider {
    struct PreviewContainer: View {
        @State private var section1Expanded = true
        @State private var section2Expanded = false

        var body: some View {
            ScreenContainer {
                VStack(spacing: .spacingLG) {
                    // Basic Section Header
                    SectionHeader(
                        title: "Recent Bills"
                    )

                    Divider()

                    // Section Header with Action
                    SectionHeader(
                        title: "Recent Bills",
                        actionTitle: "See All"
                    ) {
                        print("See all tapped")
                    }

                    Divider()

                    // Section Header with Subtitle
                    SectionHeaderWithSubtitle(
                        title: "Payment History",
                        subtitle: "Last 30 days",
                        actionTitle: "View All"
                    ) {
                        print("View all tapped")
                    }

                    Divider()

                    // Icon Section Header
                    IconSectionHeader(
                        title: "Notifications",
                        icon: "bell.fill",
                        iconColor: .accentColor,
                        actionTitle: "Settings"
                    ) {
                        print("Settings tapped")
                    }

                    Divider()

                    // Expandable Section Headers
                    VStack(spacing: .spacingMD) {
                        ExpandableSectionHeader(
                            title: "Personal Information",
                            isExpanded: $section1Expanded
                        )

                        if section1Expanded {
                            CardView {
                                VStack(alignment: .leading, spacing: .spacingSM) {
                                    Text("Name: John Doe")
                                        .bodyStyle()
                                    Text("Email: john@example.com")
                                        .bodyStyle()
                                }
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        ExpandableSectionHeader(
                            title: "Privacy Settings",
                            isExpanded: $section2Expanded
                        )

                        if section2Expanded {
                            CardView {
                                StyledToggle(
                                    label: "Share activity",
                                    isOn: .constant(true)
                                )
                            }
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
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

// MARK: - Usage Examples
/*

 Basic Section Header:
 ```
 VStack(spacing: .spacingLG) {
     SectionHeader(title: "Recent Activity")

     // Section content here
     ForEach(items) { item in
         ItemRow(item: item)
     }
 }
 ```

 Section Header with Action:
 ```
 SectionHeader(
     title: "Recent Bills",
     actionTitle: "See All"
 ) {
     navigateToAllBills()
 }
 ```

 Section Header with Subtitle:
 ```
 SectionHeaderWithSubtitle(
     title: "Monthly Summary",
     subtitle: "December 2024",
     actionTitle: "Details"
 ) {
     showMonthlyDetails()
 }
 ```

 Icon Section Header:
 ```
 IconSectionHeader(
     title: "Notifications",
     icon: "bell.fill",
     iconColor: .blue,
     actionTitle: "Settings"
 ) {
     openNotificationSettings()
 }
 ```

 Expandable Section:
 ```
 @State private var isExpanded = false

 VStack(spacing: .spacingMD) {
     ExpandableSectionHeader(
         title: "Advanced Settings",
         isExpanded: $isExpanded
     )

     if isExpanded {
         AdvancedSettingsView()
             .transition(.opacity)
     }
 }
 ```

 Complete Screen with Sections:
 ```
 ScreenContainer {
     VStack(spacing: .paddingSection) {
         SectionHeader(
             title: "Active Bills",
             actionTitle: "See All"
         ) {
             navigateToAllBills()
         }

         ForEach(activeBills) { bill in
             BillCard(bill: bill)
         }

         SectionHeader(
             title: "Settled Bills",
             actionTitle: "History"
         ) {
             navigateToHistory()
         }

         ForEach(settledBills) { bill in
             BillCard(bill: bill)
         }
     }
 }
 ```

 */
