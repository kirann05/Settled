//
//  ScreenContainer.swift
//  Settled Design System
//
//  Reusable screen container for consistent screen layouts
//  Includes standard padding, scrolling, and background
//

import SwiftUI

// MARK: - Screen Container
/// Standard screen container with scrolling and consistent padding
/// Use for: Screen-level layouts, main content views, scrollable content
struct ScreenContainer<Content: View>: View {
    let content: Content
    var useScrollView: Bool = true
    var verticalSpacing: CGFloat = .paddingSection

    init(
        useScrollView: Bool = true,
        verticalSpacing: CGFloat = .paddingSection,
        @ViewBuilder content: () -> Content
    ) {
        self.useScrollView = useScrollView
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    var body: some View {
        Group {
            if useScrollView {
                ScrollView {
                    VStack(spacing: verticalSpacing) {
                        content
                    }
                    .padding(.paddingScreen)
                }
            } else {
                VStack(spacing: verticalSpacing) {
                    content
                }
                .padding(.paddingScreen)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.adaptiveDepth0.ignoresSafeArea())
    }
}

// MARK: - Full Screen Container
/// Full screen container without padding for custom layouts
/// Use for: Full-screen experiences, custom layouts, edge-to-edge content
struct FullScreenContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.adaptiveDepth0.ignoresSafeArea())
    }
}

// MARK: - Tab Container
/// Container optimized for tab bar screens
/// Use for: Tab bar views, navigation stacks, main screens
struct TabContainer<Content: View>: View {
    let title: String?
    let content: Content
    var verticalSpacing: CGFloat = .paddingSection

    init(
        title: String? = nil,
        verticalSpacing: CGFloat = .paddingSection,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    var body: some View {
        NavigationView {
            ScreenContainer(verticalSpacing: verticalSpacing) {
                content
            }
            .navigationTitle(title ?? "")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Compact Container
/// Container with reduced padding for compact layouts
/// Use for: Modals, sheets, compact screens
struct CompactContainer<Content: View>: View {
    let content: Content
    var useScrollView: Bool = true

    init(
        useScrollView: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.useScrollView = useScrollView
        self.content = content()
    }

    var body: some View {
        Group {
            if useScrollView {
                ScrollView {
                    VStack(spacing: .spacingLG) {
                        content
                    }
                    .padding(.spacingMD)
                }
            } else {
                VStack(spacing: .spacingLG) {
                    content
                }
                .padding(.spacingMD)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.adaptiveDepth0.ignoresSafeArea())
    }
}

// MARK: - Preview Provider
struct ScreenContainer_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard Screen Container
            ScreenContainer {
                VStack(spacing: .spacingLG) {
                    Text("Screen Container")
                        .heading1()

                    CardView {
                        VStack(alignment: .leading, spacing: .spacingMD) {
                            Text("Content Section 1")
                                .heading3()
                            Text("This is a screen with standard padding and scrolling")
                                .bodyStyle()
                        }
                    }

                    CardView {
                        VStack(alignment: .leading, spacing: .spacingMD) {
                            Text("Content Section 2")
                                .heading3()
                            Text("Sections are spaced with paddingSection")
                                .bodyStyle()
                        }
                    }

                    // Spacer content to show scrolling
                    ForEach(0..<3) { index in
                        CardView {
                            Text("Card \(index + 3)")
                                .bodyStyle()
                        }
                    }
                }
            }
            .previewDisplayName("Screen Container")

            // Tab Container
            TabContainer(title: "Home") {
                VStack(spacing: .spacingLG) {
                    Text("Tab Container Example")
                        .heading2()

                    CardView {
                        Text("With navigation title")
                            .bodyStyle()
                    }
                }
            }
            .previewDisplayName("Tab Container")

            // Full Screen Container
            FullScreenContainer {
                VStack {
                    Spacer()
                    VStack(spacing: .spacingLG) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.adaptiveAccentGreen)
                        Text("Success!")
                            .heading1()
                        Text("Full screen, no padding")
                            .bodyStyle()
                    }
                    Spacer()
                }
            }
            .previewDisplayName("Full Screen Container")

            // Compact Container
            CompactContainer {
                VStack(spacing: .spacingMD) {
                    Text("Compact Container")
                        .heading3()

                    StyledToggle(
                        label: "Enable notifications",
                        isOn: .constant(true)
                    )

                    StyledToggle(
                        label: "Dark mode",
                        isOn: .constant(false)
                    )

                    Button("Save") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                }
            }
            .previewDisplayName("Compact Container")

            // Non-scrolling Container
            ScreenContainer(useScrollView: false) {
                VStack {
                    Text("Fixed Layout")
                        .heading2()

                    Spacer()

                    Button("Action") {}
                        .buttonStyle(PrimaryButtonStyle())
                        .frame(maxWidth: .infinity)
                }
            }
            .previewDisplayName("Non-Scrolling")
        }
    }
}

// MARK: - Usage Examples
/*

 Basic Screen:
 ```
 ScreenContainer {
     VStack(spacing: .spacingLG) {
         Text("Welcome")
             .heading1()

         CardView {
             Text("Content here")
         }
     }
 }
 ```

 Tab Screen with Navigation:
 ```
 TabContainer(title: "Dashboard") {
     VStack(spacing: .spacingLG) {
         SectionHeader(title: "Recent Bills")

         ForEach(bills) { bill in
             BillRowView(bill: bill)
         }
     }
 }
 ```

 Full Screen Experience:
 ```
 FullScreenContainer {
     ZStack {
         // Custom layout without padding
         Color.adaptiveAccentBlue.ignoresSafeArea()

         VStack {
             Text("Full Screen")
                 .heading1()
                 .foregroundColor(.white)
         }
     }
 }
 ```

 Modal or Sheet:
 ```
 CompactContainer {
     VStack(spacing: .spacingLG) {
         Text("Settings")
             .heading2()

         StyledToggle(label: "Notifications", isOn: $enabled)

         Button("Save") { }
             .buttonStyle(PrimaryButtonStyle())
     }
 }
 ```

 Fixed Layout (No Scroll):
 ```
 ScreenContainer(useScrollView: false) {
     VStack {
         HeaderView()

         Spacer()

         FooterView()
     }
 }
 ```

 Custom Spacing:
 ```
 ScreenContainer(verticalSpacing: .spacingLG) {
     // Tighter spacing between sections
 }
 ```

 */
