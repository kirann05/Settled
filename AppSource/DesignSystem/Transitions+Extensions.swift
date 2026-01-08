import SwiftUI

// MARK: - Custom Transitions
// Shared axis and custom transitions for Airbnb-inspired animations

extension AnyTransition {
    /// Slide up transition with opacity
    static var slideUp: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        )
    }

    /// Slide down transition with opacity
    static var slideDown: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }

    /// Fade with subtle scale
    static var fadeScale: AnyTransition {
        .scale(scale: 0.95).combined(with: .opacity)
    }

    /// Fade with grow scale (for modals)
    static var fadeGrow: AnyTransition {
        .scale(scale: 1.05).combined(with: .opacity)
    }

    /// Shared axis transition (for navigation)
    static var sharedAxis: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
}

// MARK: - View Extensions for Animations

extension View {
    /// Applies smooth scale effect on button press
    func pressableScale(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }

    /// Applies card interaction scale
    func cardPressScale(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPressed)
    }
}
