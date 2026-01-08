
import SwiftUI

// MARK: - Primary Button Style
/// Airbnb-style Primary Action Button
/// Brand color, bold text, pill-shaped/rounded-rect
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color.brandPrimary)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Secondary Button Style
/// Outlined button for secondary actions
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.textPrimary)
            .padding(.vertical, 13)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color.clear)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.textPrimary, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
    }
}

// MARK: - Tertiary Button Style
/// Text only link style
struct TertiaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.textSecondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(configuration.isPressed ? Color.gray.opacity(0.1) : Color.clear)
            .cornerRadius(6)
            .underline()
    }
}

// MARK: - Destructive Button Style
struct DestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
            .background(Color.feedbackError)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

// MARK: - Preview Provider
struct ButtonStyles_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            Button("Primary Action") {}
                .buttonStyle(PrimaryButtonStyle())

            Button("Secondary Action") {}
                .buttonStyle(SecondaryButtonStyle())

            Button("Tertiary Action") {}
                .buttonStyle(TertiaryButtonStyle())

            Button("Destructive Action") {}
                .buttonStyle(DestructiveButtonStyle())
        }
        .padding(32)
        .background(Color.adaptiveBackground)
        .previewLayout(.sizeThatFits)
    }
}
