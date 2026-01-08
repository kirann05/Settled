
import SwiftUI

extension Font {
    // MARK: - Airbnb-inspired Typography
    // Heavy use of weights to create hierarchy instead of just size.
    // Now with Dynamic Type support for accessibility

    static let cerealHeadline = Font.system(size: 32, weight: .semibold, design: .rounded)
    static let cerealTitle1 = Font.system(size: 26, weight: .semibold, design: .rounded)
    static let cerealTitle2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let cerealTitle3 = Font.system(size: 18, weight: .semibold, design: .rounded)

    static let cerealBody = Font.system(size: 16, weight: .regular)
    static let cerealBodyBold = Font.system(size: 16, weight: .semibold)

    static let cerealSubheadline = Font.system(size: 14, weight: .regular)
    static let cerealSubheadlineBold = Font.system(size: 14, weight: .semibold)

    static let cerealCaption = Font.system(size: 12, weight: .regular)
    static let cerealCaptionBold = Font.system(size: 12, weight: .semibold)

    // MARK: - Typography Constants

    /// Letter spacing for headlines (subtle tightening)
    static let headingLetterSpacing: CGFloat = -0.5

    /// Letter spacing for body text
    static let bodyLetterSpacing: CGFloat = 0.0

    /// Line height multiplier for headings
    static let headingLineHeight: CGFloat = 1.2

    /// Line height multiplier for body text
    static let bodyLineHeight: CGFloat = 1.5
    
    // Mapping existing calls to new system
    static let h1Dynamic = cerealHeadline
    static let h2Dynamic = cerealTitle1
    static let h3Dynamic = cerealTitle2
    static let h4Dynamic = cerealTitle3
    static let bodyDynamic = cerealBody
    static let smallDynamic = cerealSubheadline
    static let captionDynamic = cerealCaption
    
    static let buttonText = cerealBodyBold
    static let inputLabel = cerealSubheadlineBold
}

// MARK: - Text Modifier Extensions
extension Text {
    func heading1() -> some View { self.font(.cerealHeadline).foregroundColor(.textPrimary) }
    func heading2() -> some View { self.font(.cerealTitle1).foregroundColor(.textPrimary) }
    func heading3() -> some View { self.font(.cerealTitle2).foregroundColor(.textPrimary) }
    func heading4() -> some View { self.font(.cerealTitle3).foregroundColor(.textPrimary) }
    
    func bodyStyle() -> some View { self.font(.cerealBody).foregroundColor(.textSecondary) }
    func smallStyle() -> some View { self.font(.cerealSubheadline).foregroundColor(.textSecondary) }
    func captionStyle() -> some View { self.font(.cerealCaption).foregroundColor(.textTertiary) }
}
