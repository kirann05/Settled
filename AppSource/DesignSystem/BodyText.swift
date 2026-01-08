//
//  BodyText.swift
//  Settled Design System
//
//  Reusable body text component with text hierarchy
//  Supports primary, secondary, and tertiary text styles
//

import SwiftUI

// MARK: - Body Text
/// Semantic body text with style-based color hierarchy
/// Use for: Main content, descriptions, body copy
struct BodyText: View {
    let text: String
    let style: TextStyle
    var lineSpacing: CGFloat = 6
    var lineLimit: Int? = nil

    enum TextStyle {
        case primary, secondary, tertiary

        var color: Color {
            switch self {
            case .primary: return .adaptiveTextPrimary
            case .secondary: return .adaptiveTextSecondary
            case .tertiary: return .adaptiveTextTertiary
            }
        }

        var font: Font {
            .bodyDynamic
        }
    }

    var body: some View {
        Text(text)
            .font(style.font)
            .foregroundColor(style.color)
            .lineSpacing(lineSpacing)
            .lineLimit(lineLimit)
    }
}

// MARK: - Small Text
/// Small text component for secondary information
/// Use for: Captions, metadata, timestamps, helper text
struct SmallText: View {
    let text: String
    var style: TextStyle = .secondary
    var lineLimit: Int? = nil

    enum TextStyle {
        case primary, secondary, tertiary

        var color: Color {
            switch self {
            case .primary: return .adaptiveTextPrimary
            case .secondary: return .adaptiveTextSecondary
            case .tertiary: return .adaptiveTextTertiary
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.smallDynamic)
            .foregroundColor(style.color)
            .lineLimit(lineLimit)
    }
}

// MARK: - Caption Text
/// Caption text for fine print and timestamps
/// Use for: Timestamps, fine print, subtle information
struct CaptionText: View {
    let text: String
    var style: TextStyle = .tertiary

    enum TextStyle {
        case primary, secondary, tertiary

        var color: Color {
            switch self {
            case .primary: return .adaptiveTextPrimary
            case .secondary: return .adaptiveTextSecondary
            case .tertiary: return .adaptiveTextTertiary
            }
        }
    }

    var body: some View {
        Text(text)
            .font(.captionDynamic)
            .foregroundColor(style.color)
    }
}

// MARK: - Highlighted Text
/// Text with background highlight
/// Use for: Emphasis, badges, inline labels
struct HighlightedText: View {
    let text: String
    var backgroundColor: Color = .accentColor.opacity(0.2)
    var textColor: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.cerealCaption)
            .foregroundColor(textColor)
            .padding(.horizontal, .spacingSM)
            .padding(.vertical, .spacingXS)
            .background(backgroundColor)
            .cornerRadius(.cornerRadiusSmall)
    }
}

// MARK: - Link Text
/// Styled link text with underline
/// Use for: Clickable links, navigation text
struct LinkText: View {
    let text: String
    let action: () -> Void
    var showUnderline: Bool = true

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.bodyDynamic)
                .foregroundColor(.accentColor)
                .underline(showUnderline)
        }
    }
}

// MARK: - Preview Provider
struct BodyText_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light Mode
            ScreenContainer {
                VStack(alignment: .leading, spacing: .spacingXL) {
                    // Body Text Styles
                    VStack(alignment: .leading, spacing: .spacingMD) {
                        Text("Body Text Styles")
                            .heading3()

                        BodyText(
                            text: "Primary body text - Used for main content and important information",
                            style: .primary
                        )

                        BodyText(
                            text: "Secondary body text - Used for supporting information and descriptions",
                            style: .secondary
                        )

                        BodyText(
                            text: "Tertiary body text - Used for less important details and hints",
                            style: .tertiary
                        )
                    }

                    Divider()

                    // Small Text Styles
                    VStack(alignment: .leading, spacing: .spacingMD) {
                        Text("Small Text Styles")
                            .heading3()

                        SmallText(
                            text: "Primary small text",
                            style: .primary
                        )

                        SmallText(
                            text: "Secondary small text - default style",
                            style: .secondary
                        )

                        SmallText(
                            text: "Tertiary small text",
                            style: .tertiary
                        )
                    }

                    Divider()

                    // Caption Text
                    VStack(alignment: .leading, spacing: .spacingMD) {
                        Text("Caption Styles")
                            .heading3()

                        CaptionText(text: "Last updated: 2 minutes ago", style: .tertiary)
                        CaptionText(text: "Version 1.0.0", style: .secondary)
                    }

                    Divider()

                    // Highlighted Text
                    VStack(alignment: .leading, spacing: .spacingMD) {
                        Text("Highlighted Text")
                            .heading3()

                        HStack(spacing: .spacingSM) {
                            HighlightedText(text: "New")

                            HighlightedText(
                                text: "Premium",
                                backgroundColor: .purple.opacity(0.2),
                                textColor: .purple
                            )

                            HighlightedText(
                                text: "Beta",
                                backgroundColor: .orange.opacity(0.2),
                                textColor: .orange
                            )
                        }
                    }

                    Divider()

                    // Link Text
                    VStack(alignment: .leading, spacing: .spacingMD) {
                        Text("Links")
                            .heading3()

                        LinkText(text: "Learn more") {
                            print("Link tapped")
                        }

                        LinkText(text: "View details", showUnderline: false) {
                            print("Link tapped")
                        }
                    }

                    Divider()

                    // Real World Example
                    CardView {
                        VStack(alignment: .leading, spacing: .spacingMD) {
                            HStack {
                                HeadingText(text: "Bill Payment", level: .h4)
                                Spacer()
                                HighlightedText(text: "Pending")
                            }

                            BodyText(
                                text: "You owe $45.00 to John Doe for dinner at Restaurant ABC",
                                style: .primary
                            )

                            SmallText(
                                text: "Split equally among 4 participants",
                                style: .secondary
                            )

                            CaptionText(
                                text: "Created on Dec 15, 2024 at 7:30 PM",
                                style: .tertiary
                            )

                            LinkText(text: "View full details", showUnderline: true) {
                                print("View details")
                            }
                        }
                    }
                }
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

            // Dark Mode
            ScreenContainer {
                VStack(alignment: .leading, spacing: .spacingLG) {
                    BodyText(text: "Dark mode body text", style: .primary)
                    SmallText(text: "Dark mode small text", style: .secondary)
                    CaptionText(text: "Dark mode caption", style: .tertiary)
                }
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply body text style directly to any text view
    func bodyStyle(_ style: BodyText.TextStyle = .primary, lineSpacing: CGFloat = 6) -> some View {
        self.modifier(BodyTextModifier(style: style, lineSpacing: lineSpacing))
    }

    /// Apply small text style directly to any text view
    func smallStyle(_ style: SmallText.TextStyle = .secondary) -> some View {
        self.modifier(SmallTextModifier(style: style))
    }

    /// Apply caption text style directly to any text view
    func captionStyle(_ style: CaptionText.TextStyle = .tertiary) -> some View {
        self.modifier(CaptionTextModifier(style: style))
    }
}

// MARK: - Text Style Modifiers
struct BodyTextModifier: ViewModifier {
    let style: BodyText.TextStyle
    let lineSpacing: CGFloat

    func body(content: Content) -> some View {
        content
            .font(style.font)
            .foregroundColor(style.color)
            .lineSpacing(lineSpacing)
    }
}

struct SmallTextModifier: ViewModifier {
    let style: SmallText.TextStyle

    func body(content: Content) -> some View {
        content
            .font(.smallDynamic)
            .foregroundColor(style.color)
    }
}

struct CaptionTextModifier: ViewModifier {
    let style: CaptionText.TextStyle

    func body(content: Content) -> some View {
        content
            .font(.captionDynamic)
            .foregroundColor(style.color)
    }
}

// MARK: - Usage Examples
/*

 Basic Body Text:
 ```
 BodyText(
     text: "This is the main content of the message",
     style: .primary
 )
 ```

 Small Text:
 ```
 SmallText(
     text: "Additional details here",
     style: .secondary
 )
 ```

 Caption:
 ```
 CaptionText(
     text: "Posted 5 minutes ago",
     style: .tertiary
 )
 ```

 Highlighted Badge:
 ```
 HighlightedText(
     text: "New Feature",
     backgroundColor: .green.opacity(0.2),
     textColor: .green
 )
 ```

 Link:
 ```
 LinkText(text: "Read more") {
     openArticle()
 }
 ```

 Using Modifiers:
 ```
 Text("Main content")
     .bodyStyle(.primary)

 Text("Supporting text")
     .smallStyle(.secondary)

 Text("Timestamp")
     .captionStyle(.tertiary)
 ```

 Card Example:
 ```
 CardView {
     VStack(alignment: .leading, spacing: .spacingMD) {
         HeadingText(text: "Notification", level: .h4)

         BodyText(
             text: "You have a new message from Sarah",
             style: .primary
         )

         SmallText(
             text: "Tap to view conversation",
             style: .secondary
         )

         CaptionText(
             text: "2 minutes ago",
             style: .tertiary
         )
     }
 }
 ```

 */
