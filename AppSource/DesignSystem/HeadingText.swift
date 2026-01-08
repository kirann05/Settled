//
//  HeadingText.swift
//  Settled Design System
//
//  Reusable heading component with typography hierarchy
//  Supports h1 through h4 with Dynamic Type
//

import SwiftUI

// MARK: - Heading Text
/// Semantic heading text with level-based styling
/// Use for: Screen titles, section headers, content hierarchy
struct HeadingText: View {
    let text: String
    let level: HeadingLevel
    var color: Color = .adaptiveTextPrimary
    var lineSpacing: CGFloat = 2

    enum HeadingLevel {
        case h1, h2, h3, h4

        var font: Font {
            switch self {
            case .h1: return .h1Dynamic
            case .h2: return .h2Dynamic
            case .h3: return .h3Dynamic
            case .h4: return .h4Dynamic
            }
        }

        var accessibilityLevel: AccessibilityHeadingLevel {
            switch self {
            case .h1: return .h1
            case .h2: return .h2
            case .h3: return .h3
            case .h4: return .h4
            }
        }
    }

    var body: some View {
        Text(text)
            .font(level.font)
            .foregroundColor(color)
            .lineSpacing(lineSpacing)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level.accessibilityLevel)
    }
}

// MARK: - Multiline Heading
/// Heading with support for long text and line limits
/// Use for: Longer titles, wrapping headings, dynamic content
struct MultilineHeading: View {
    let text: String
    let level: HeadingText.HeadingLevel
    var color: Color = .adaptiveTextPrimary
    var lineLimit: Int? = nil

    var body: some View {
        Text(text)
            .font(level.font)
            .foregroundColor(color)
            .lineLimit(lineLimit)
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level.accessibilityLevel)
    }
}

// MARK: - Gradient Heading
/// Heading with gradient text effect
/// Use for: Hero sections, prominent titles, branding
struct GradientHeading: View {
    let text: String
    let level: HeadingText.HeadingLevel
    var gradient: LinearGradient = LinearGradient(
        colors: [.accentColor, .blue],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        Text(text)
            .font(level.font)
            .foregroundStyle(gradient)
            .lineSpacing(2)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level.accessibilityLevel)
    }
}

// MARK: - Decorated Heading
/// Heading with decorative underline or accent
/// Use for: Section emphasis, visual separation
struct DecoratedHeading: View {
    let text: String
    let level: HeadingText.HeadingLevel
    var accentColor: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: .spacingSM) {
            Text(text)
                .font(level.font)
                .foregroundColor(.adaptiveTextPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityHeading(level.accessibilityLevel)

            Rectangle()
                .fill(accentColor)
                .frame(width: 40, height: 4)
                .cornerRadius(2)
        }
    }
}

// MARK: - Preview Provider
struct HeadingText_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Light Mode
            ScreenContainer {
                VStack(alignment: .leading, spacing: .spacingXL) {
                    // All Heading Levels
                    VStack(alignment: .leading, spacing: .spacingLG) {
                        HeadingText(text: "Heading 1", level: .h1)
                        HeadingText(text: "Heading 2", level: .h2)
                        HeadingText(text: "Heading 3", level: .h3)
                        HeadingText(text: "Heading 4", level: .h4)
                    }

                    Divider()

                    // Multiline Heading
                    MultilineHeading(
                        text: "This is a very long heading that will wrap to multiple lines when needed",
                        level: .h2,
                        lineLimit: 3
                    )

                    Divider()

                    // Gradient Heading
                    GradientHeading(
                        text: "Premium Feature",
                        level: .h1
                    )

                    Divider()

                    // Decorated Heading
                    DecoratedHeading(
                        text: "Featured Section",
                        level: .h2,
                        accentColor: .accentColor
                    )

                    Divider()

                    // Color Variations
                    VStack(alignment: .leading, spacing: .spacingMD) {
                        HeadingText(
                            text: "Primary Heading",
                            level: .h3,
                            color: .adaptiveTextPrimary
                        )

                        HeadingText(
                            text: "Accent Heading",
                            level: .h3,
                            color: .accentColor
                        )

                        HeadingText(
                            text: "Secondary Heading",
                            level: .h4,
                            color: .adaptiveTextSecondary
                        )
                    }
                }
            }
            .preferredColorScheme(.light)
            .previewDisplayName("Light Mode")

            // Dark Mode
            ScreenContainer {
                VStack(alignment: .leading, spacing: .spacingXL) {
                    HeadingText(text: "Dark Mode", level: .h1)
                    HeadingText(text: "Heading 2", level: .h2)
                    GradientHeading(text: "Gradient", level: .h2)
                }
            }
            .preferredColorScheme(.dark)
            .previewDisplayName("Dark Mode")

            // Accessibility Sizes
            ScreenContainer {
                VStack(alignment: .leading, spacing: .spacingLG) {
                    Text("Accessibility: Extra Large")
                        .font(.caption)
                        .foregroundColor(.adaptiveTextTertiary)

                    HeadingText(text: "Scales with Dynamic Type", level: .h2)
                    HeadingText(text: "Maintains hierarchy", level: .h3)
                }
            }
            .environment(\.sizeCategory, .accessibilityExtraLarge)
            .previewDisplayName("Accessibility XL")
        }
    }
}

// MARK: - View Extensions
extension View {
    /// Apply heading style directly to any text view
    func headingStyle(_ level: HeadingText.HeadingLevel, color: Color = .adaptiveTextPrimary) -> some View {
        self.modifier(HeadingStyleModifier(level: level, color: color))
    }
}

// MARK: - Heading Style Modifier
struct HeadingStyleModifier: ViewModifier {
    let level: HeadingText.HeadingLevel
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(level.font)
            .foregroundColor(color)
            .lineSpacing(2)
            .accessibilityAddTraits(.isHeader)
            .accessibilityHeading(level.accessibilityLevel)
    }
}

// MARK: - Usage Examples
/*

 Basic Heading:
 ```
 HeadingText(text: "Welcome Back", level: .h1)
 ```

 Heading with Color:
 ```
 HeadingText(
     text: "Important Notice",
     level: .h2,
     color: .red
 )
 ```

 Multiline Heading:
 ```
 MultilineHeading(
     text: "This is a very long title that may span multiple lines",
     level: .h2,
     lineLimit: 2
 )
 ```

 Gradient Heading:
 ```
 GradientHeading(
     text: "Premium Feature",
     level: .h1,
     gradient: LinearGradient(
         colors: [.purple, .blue],
         startPoint: .topLeading,
         endPoint: .bottomTrailing
     )
 )
 ```

 Decorated Section:
 ```
 DecoratedHeading(
     text: "Featured Bills",
     level: .h3,
     accentColor: .green
 )
 ```

 Using Modifier:
 ```
 Text("Quick Access")
     .headingStyle(.h3, color: .accentColor)
 ```

 Screen Layout:
 ```
 ScreenContainer {
     VStack(alignment: .leading, spacing: .spacingLG) {
         HeadingText(text: "Dashboard", level: .h1)

         DecoratedHeading(text: "Recent Activity", level: .h3)

         // Content here

         HeadingText(text: "Quick Actions", level: .h4)

         // Actions here
     }
 }
 ```

 Card with Heading:
 ```
 CardView {
     VStack(alignment: .leading, spacing: .spacingMD) {
         HeadingText(text: "Bill Summary", level: .h3)

         Text("Total amount: $124.50")
             .bodyStyle()
     }
 }
 ```

 */
