//
//  CGFloat+Spacing.swift
//  Settled Design System
//
//  Consistent spacing scale based on multiples of 4
//  Provides semantic spacing values for layout consistency
//

import SwiftUI

extension CGFloat {
    // MARK: - Base Spacing Scale
    // All spacing should use these predefined values
    // Based on 4px/8px grid system for visual harmony

    /// 2X Extra Small spacing - 2px
    /// Use for: Very tight spacing, minimal gaps
    static let spacing2XS: CGFloat = 2

    /// Extra Small spacing - 4px
    /// Use for: Tight element spacing, icon padding
    static let spacingXS: CGFloat = 4

    /// Small-Medium spacing - 6px
    /// Use for: Icon-to-text spacing, compact element gaps
    static let spacingXSM: CGFloat = 6

    /// Small spacing - 8px
    /// Use for: Label-to-control spacing, compact layouts
    static let spacingSM: CGFloat = 8

    /// Medium-Large spacing - 12px
    /// Use for: Moderate element separation, form field spacing
    static let spacingML: CGFloat = 12

    /// Medium spacing - 16px (Default)
    /// Use for: Standard padding, element separation
    static let spacingMD: CGFloat = 16

    /// Large spacing - 24px
    /// Use for: Section spacing, card internal padding
    static let spacingLG: CGFloat = 24

    /// Extra Large spacing - 32px
    /// Use for: Major section breaks, screen padding
    static let spacingXL: CGFloat = 32

    /// Extra Extra Large spacing - 40px
    /// Use for: Large content separation, major gaps
    static let spacingXXL: CGFloat = 40

    /// 2X Large spacing - 48px
    /// Use for: Large section separation, feature spacing
    static let spacing2XL: CGFloat = 48

    /// 3X Large spacing - 64px
    /// Use for: Major visual breaks, hero sections
    static let spacing3XL: CGFloat = 64

    // MARK: - Semantic Spacing
    // Context-specific spacing values for common use cases

    /// Standard padding for card interiors
    /// Provides comfortable breathing room for content
    static let paddingCard: CGFloat = 24

    /// Standard screen edge padding
    /// Consistent margin for screen-level content
    static let paddingScreen: CGFloat = 16

    /// Padding between major sections
    /// Creates clear visual separation
    static let paddingSection: CGFloat = 32

    // MARK: - Corner Radius
    // Consistent border radius values

    /// Small corner radius - 8px
    /// Use for: Small cards, inputs
    static let cornerRadiusSmall: CGFloat = 8

    /// Medium corner radius - 12px
    /// Use for: Cards, containers, medium UI elements
    static let cornerRadiusMedium: CGFloat = 12

    /// Large corner radius - 16px
    /// Use for: Large cards, modals, prominent containers
    static let cornerRadiusLarge: CGFloat = 16

    /// Button corner radius - 24px
    /// Use for: All buttons to achieve highly rounded appearance
    static let cornerRadiusButton: CGFloat = 24
}

// MARK: - EdgeInsets Extensions
// Pre-configured padding sets for common layouts

extension EdgeInsets {
    /// Standard card padding (24px all sides)
    /// Use for: Card interiors, content containers
    static let cardPadding = EdgeInsets(
        top: .paddingCard,
        leading: .paddingCard,
        bottom: .paddingCard,
        trailing: .paddingCard
    )

    /// Standard screen padding (16px all sides)
    /// Use for: Screen-level content, main containers
    static let screenPadding = EdgeInsets(
        top: .paddingScreen,
        leading: .paddingScreen,
        bottom: .paddingScreen,
        trailing: .paddingScreen
    )

    /// Section padding with larger vertical spacing
    /// Use for: Major sections with emphasis
    static let sectionPadding = EdgeInsets(
        top: .paddingSection,
        leading: .paddingScreen,
        bottom: .paddingSection,
        trailing: .paddingScreen
    )
}

// MARK: - Usage Examples
/*

 Basic Spacing:
 ```
 VStack(spacing: .spacingLG) {
     Text("Item 1")
     Text("Item 2")
 }
 .padding(.spacingMD)
 ```

 Card Padding:
 ```
 VStack {
     Text("Card Content")
 }
 .padding(.paddingCard)
 .background(Color.adaptiveDepth2)
 .cornerRadius(.cornerRadiusMedium)
 ```

 Screen Layout:
 ```
 ScrollView {
     VStack(spacing: .paddingSection) {
         Section1()
         Section2()
     }
     .padding(.paddingScreen)
 }
 ```

 EdgeInsets Usage:
 ```
 .listRowInsets(.cardPadding)
 ```

 */
