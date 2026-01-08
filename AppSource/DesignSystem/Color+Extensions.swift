import SwiftUI

extension Color {
    // MARK: - Airbnb-inspired Color System
    // Clean, minimalist, white-heavy design with specific brand accents.
    
    // MARK: - Brand Colors
    
    /// Primary Brand Color (Rausch) - Used for primary actions, heavy emphasis
    static var brandPrimary: Color {
        Color(UIColor(red: 1.0, green: 0.35, blue: 0.37, alpha: 1.0)) // #FF5A5F
    }
    
    /// Secondary Brand Color (Babu) - Teal/Green for calm actions
    static var brandSecondary: Color {
        Color(UIColor(red: 0.0, green: 0.52, blue: 0.54, alpha: 1.0)) // #008489
    }

    // MARK: - Surface Architecture
    
    /// Main background - Pure white in light mode, dark gray in dark mode
    static var adaptiveBackground: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0)
                : UIColor.white
        })
    }
    
    /// Secondary background - Very subtle gray for differentiation
    static var adaptiveBackgroundSecondary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
                : UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0) // F7F7F7
        })
    }
    
    /// Card background - White with shadow capability, distinct in dark mode
    static var adaptiveSurface: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
                : UIColor.white
        })
    }
    
    // MARK: - Text Colors
    
    /// Primary Text - High contrast
    static var textPrimary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
                : UIColor(red: 0.13, green: 0.13, blue: 0.13, alpha: 1.0) // #222222
        })
    }
    
    /// Secondary Text - Medium contrast for body
    static var textSecondary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 1.0)
                : UIColor(red: 0.44, green: 0.44, blue: 0.44, alpha: 1.0) // #717171
        })
    }
    
    /// Tertiary Text - Low contrast for placeholders/disabled
    static var textTertiary: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
                : UIColor(red: 0.68, green: 0.68, blue: 0.68, alpha: 1.0) // #B0B0B0
        })
    }

    // MARK: - Borders & Dividers
    
    static var adaptiveBorder: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
                : UIColor(red: 0.92, green: 0.92, blue: 0.92, alpha: 1.0) // #EBEBEB
        })
    }

    // MARK: - Semantic Colors (Feedback)

    static var feedbackSuccess: Color {
        Color(UIColor(red: 0.0, green: 0.5, blue: 0.35, alpha: 1.0)) // Darker green
    }

    static var feedbackError: Color {
        Color(UIColor(red: 0.75, green: 0.15, blue: 0.15, alpha: 1.0)) // Deep red
    }

    static var feedbackWarning: Color {
        Color(UIColor(red: 0.85, green: 0.55, blue: 0.0, alpha: 1.0)) // Amber
    }

    static var feedbackInfo: Color {
        Color(UIColor(red: 0.0, green: 0.48, blue: 0.87, alpha: 1.0)) // Info blue
    }

    // MARK: - Surface Hierarchy (Enhanced)

    /// Elevated surface for cards on backgrounds
    static var surfaceElevated: Color { adaptiveSurface }

    /// Subtle surface for nested content
    static var surfaceSubtle: Color { adaptiveBackgroundSecondary }

    // MARK: - Interactive States

    static var interactiveHover: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.25, alpha: 1.0)
                : UIColor(white: 0.95, alpha: 1.0)
        })
    }

    static var interactivePressed: Color {
        Color(UIColor { traitCollection in
            traitCollection.userInterfaceStyle == .dark
                ? UIColor(white: 0.30, alpha: 1.0)
                : UIColor(white: 0.90, alpha: 1.0)
        })
    }

    static var interactiveDisabled: Color {
        textTertiary.opacity(0.3)
    }

    // MARK: - Shadow Tokens

    static var shadowLight: Color {
        Color.black.opacity(0.04)
    }

    static var shadowMedium: Color {
        Color.black.opacity(0.06)
    }

    static var shadowStrong: Color {
        Color.black.opacity(0.10)
    }

    // MARK: - Compatibility Aliases (to prevent build errors during migration)
    
    static var adaptiveDepth0: Color { adaptiveBackground }
    static var adaptiveDepth1: Color { adaptiveBackgroundSecondary }
    static var adaptiveDepth2: Color { adaptiveSurface }
    static var adaptiveDepth3: Color { adaptiveSurface }
    
    static var adaptiveTextPrimary: Color { textPrimary }
    static var adaptiveTextSecondary: Color { textSecondary }
    static var adaptiveTextTertiary: Color { textTertiary }
    
    static var adaptiveAccentBlue: Color { brandSecondary } // Mapping old blue to our secondary teal
    static var adaptiveAccentRed: Color { brandPrimary } // Mapping old red to our primary brand color
    static var adaptiveAccentGreen: Color { feedbackSuccess }
    static var adaptiveAccentOrange: Color { feedbackWarning }
    static var adaptiveMutedGreen: Color { feedbackSuccess.opacity(0.8) }
    static var adaptiveMutedRed: Color { feedbackError.opacity(0.8) }
}
