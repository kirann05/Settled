//
//  CustomListRow.swift
//  Settled Design System
//
//  Reusable list row components with consistent styling
//  Includes standard, interactive, and icon-based rows
//

import SwiftUI

// MARK: - Custom List Row
/// Standard list row with consistent design system styling
/// Use for: List items, table rows, menu items
struct CustomListRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(.spacingMD)
            .background(Color.adaptiveDepth1)
            .cornerRadius(.cornerRadiusSmall)
    }
}

// MARK: - Interactive List Row
/// Tappable list row with chevron indicator
/// Use for: Navigable items, selectable rows, actionable lists
struct InteractiveListRow<Content: View>: View {
    let content: Content
    let action: () -> Void
    @State private var isPressed = false

    init(action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: .spacingMD) {
                content

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.adaptiveTextTertiary)
            }
            .padding(.spacingMD)
            .background(Color.adaptiveDepth1)
            .cornerRadius(.cornerRadiusSmall)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.smoothSpring, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Icon List Row
/// List row with leading icon
/// Use for: Settings items, menu options, categorized lists
struct IconListRow: View {
    let title: String
    let icon: String
    let iconColor: Color
    var subtitle: String? = nil
    var showChevron: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack(spacing: .spacingMD) {
                // Icon
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)

                // Text Content
                VStack(alignment: .leading, spacing: .spacingXS) {
                    Text(title)
                        .font(.cerealBody)
                        .foregroundColor(.adaptiveTextPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.cerealSubheadline)
                            .foregroundColor(.adaptiveTextSecondary)
                    }
                }

                Spacer()

                // Chevron
                if showChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.adaptiveTextTertiary)
                }
            }
            .padding(.spacingMD)
            .background(Color.adaptiveDepth1)
            .cornerRadius(.cornerRadiusSmall)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

// MARK: - Detail List Row
/// List row with title and trailing detail
/// Use for: Key-value pairs, settings with values, informational rows
struct DetailListRow: View {
    let title: String
    let detail: String
    var action: (() -> Void)? = nil

    var body: some View {
        Button(action: { action?() }) {
            HStack {
                Text(title)
                    .font(.cerealBody)
                    .foregroundColor(.adaptiveTextPrimary)

                Spacer()

                Text(detail)
                    .font(.cerealBody)
                    .foregroundColor(.adaptiveTextSecondary)

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.adaptiveTextTertiary)
                        .padding(.leading, .spacingXS)
                }
            }
            .padding(.spacingMD)
            .background(Color.adaptiveDepth1)
            .cornerRadius(.cornerRadiusSmall)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil)
    }
}

// MARK: - Swipeable List Row
/// List row with swipe actions (delete, archive, etc.)
/// Use for: Deletable items, swipe-to-action lists
struct SwipeableListRow<Content: View>: View {
    let content: Content
    var onDelete: (() -> Void)? = nil
    var onArchive: (() -> Void)? = nil

    @State private var offset: CGFloat = 0

    init(
        onDelete: (() -> Void)? = nil,
        onArchive: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.onDelete = onDelete
        self.onArchive = onArchive
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            // Action Buttons Background
            HStack(spacing: 0) {
                if let onArchive = onArchive {
                    Button(action: {
                        withAnimation(.smoothSpring) {
                            onArchive()
                            offset = 0
                        }
                    }) {
                        Image(systemName: "archivebox.fill")
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.adaptiveAccentOrange)
                    }
                }

                if let onDelete = onDelete {
                    Button(action: {
                        withAnimation(.smoothSpring) {
                            onDelete()
                        }
                    }) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(Color.adaptiveAccentRed)
                    }
                }
            }
            .cornerRadius(.cornerRadiusSmall)

            // Main Content
            content
                .padding(.spacingMD)
                .background(Color.adaptiveDepth1)
                .cornerRadius(.cornerRadiusSmall)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { gesture in
                            if gesture.translation.width < 0 {
                                offset = gesture.translation.width
                            }
                        }
                        .onEnded { gesture in
                            withAnimation(.smoothSpring) {
                                if gesture.translation.width < -100 {
                                    offset = -120
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )
        }
    }
}

// MARK: - Preview Provider
struct CustomListRow_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard List
            ScreenContainer {
                VStack(spacing: .spacingMD) {
                    Text("Custom List Rows")
                        .heading2()

                    // Basic Rows
                    CustomListRow {
                        HStack {
                            Text("Basic Row")
                                .bodyStyle(.primary)
                            Spacer()
                            Text("Value")
                                .bodyStyle(.secondary)
                        }
                    }

                    // Interactive Rows
                    InteractiveListRow(action: { print("Row tapped") }) {
                        VStack(alignment: .leading, spacing: .spacingXS) {
                            Text("Interactive Row")
                                .bodyStyle(.primary)
                            Text("Tap to navigate")
                                .smallStyle(.secondary)
                        }
                    }

                    // Icon Rows
                    IconListRow(
                        title: "Notifications",
                        icon: "bell.fill",
                        iconColor: .blue,
                        subtitle: "Manage notification settings",
                        showChevron: true,
                        action: { print("Notifications tapped") }
                    )

                    IconListRow(
                        title: "Privacy",
                        icon: "lock.fill",
                        iconColor: .green,
                        subtitle: "Control your privacy settings",
                        showChevron: true,
                        action: { print("Privacy tapped") }
                    )

                    // Detail Rows
                    DetailListRow(
                        title: "Username",
                        detail: "john_doe",
                        action: { print("Edit username") }
                    )

                    DetailListRow(
                        title: "Email",
                        detail: "john@example.com",
                        action: { print("Edit email") }
                    )

                    // Swipeable Row
                    SwipeableListRow(
                        onDelete: { print("Delete tapped") },
                        onArchive: { print("Archive tapped") }
                    ) {
                        HStack {
                            VStack(alignment: .leading, spacing: .spacingXS) {
                                Text("Swipeable Row")
                                    .bodyStyle(.primary)
                                Text("Swipe left for actions")
                                    .smallStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                }
            }
            .previewDisplayName("List Rows")

            // Settings Screen Example
            ScreenContainer {
                VStack(spacing: .spacingLG) {
                    Text("Settings")
                        .heading1()

                    VStack(spacing: .spacingMD) {
                        IconListRow(
                            title: "Account",
                            icon: "person.circle.fill",
                            iconColor: .accentColor,
                            subtitle: "Manage your account",
                            showChevron: true,
                            action: {}
                        )

                        IconListRow(
                            title: "Security",
                            icon: "lock.shield.fill",
                            iconColor: .green,
                            subtitle: "Privacy and security",
                            showChevron: true,
                            action: {}
                        )

                        IconListRow(
                            title: "Help",
                            icon: "questionmark.circle.fill",
                            iconColor: .blue,
                            subtitle: "Get help and support",
                            showChevron: true,
                            action: {}
                        )
                    }
                }
            }
            .previewDisplayName("Settings Example")
        }
    }
}

// MARK: - List Style Extension
extension View {
    /// Apply custom list row styling within a List
    func customListRowStyle() -> some View {
        self
            .listRowBackground(Color.adaptiveDepth0)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
    }
}

// MARK: - Usage Examples
/*

 Basic List Row:
 ```
 CustomListRow {
     HStack {
         Text("Item Name")
         Spacer()
         Text("$12.50")
     }
 }
 ```

 Interactive Row:
 ```
 InteractiveListRow(action: { navigateToDetail() }) {
     VStack(alignment: .leading) {
         Text("Bill #123")
         Text("Tap to view")
             .smallStyle(.secondary)
     }
 }
 ```

 Icon Row:
 ```
 IconListRow(
     title: "Settings",
     icon: "gear",
     iconColor: .gray,
     subtitle: "App preferences",
     showChevron: true,
     action: { openSettings() }
 )
 ```

 Detail Row:
 ```
 DetailListRow(
     title: "Total",
     detail: "$124.50"
 )
 ```

 In a List:
 ```
 List(items) { item in
     CustomListRow {
         Text(item.name)
     }
     .customListRowStyle()
 }
 .listStyle(.plain)
 ```

 Settings Screen:
 ```
 List {
     Section {
         IconListRow(
             title: "Profile",
             icon: "person.fill",
             iconColor: .blue,
             showChevron: true,
             action: { }
         )
         .customListRowStyle()
     }
 }
 ```

 Swipeable List:
 ```
 ForEach(bills) { bill in
     SwipeableListRow(
         onDelete: { deleteBill(bill) },
         onArchive: { archiveBill(bill) }
     ) {
         BillRowContent(bill: bill)
     }
 }
 ```

 */
