import SwiftUI

// MARK: - Elevation System
// Standardized shadow system for Airbnb-inspired depth and hierarchy

struct ElevationStyle {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    /// No shadow - flat design
    static let none = ElevationStyle(
        color: .clear,
        radius: 0,
        x: 0,
        y: 0
    )

    /// Subtle elevation - minimal depth for cards
    static let subtle = ElevationStyle(
        color: .shadowLight,
        radius: 4,
        x: 0,
        y: 2
    )

    /// Medium elevation - standard card depth
    static let medium = ElevationStyle(
        color: .shadowMedium,
        radius: 8,
        x: 0,
        y: 4
    )

    /// Strong elevation - prominent elements like modals
    static let strong = ElevationStyle(
        color: .shadowStrong,
        radius: 16,
        x: 0,
        y: 8
    )
}

// MARK: - View Extension

extension View {
    /// Applies standardized elevation shadow to view
    func elevation(_ style: ElevationStyle) -> some View {
        self.shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}
