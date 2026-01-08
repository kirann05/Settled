import SwiftUI

// MARK: - Elevated Card Component
// Card with automatic depth-based background and shadow

struct ElevatedCard<Content: View>: View {
    let depth: Int  // 1-3 depth levels
    let content: Content

    init(depth: Int = 1, @ViewBuilder content: () -> Content) {
        self.depth = min(max(depth, 1), 3) // Clamp to 1-3
        self.content = content()
    }

    var backgroundColor: Color {
        switch depth {
        case 1: return .adaptiveBackgroundSecondary
        case 2: return .surfaceElevated
        default: return .adaptiveBackground
        }
    }

    var elevationStyle: ElevationStyle {
        switch depth {
        case 1: return .subtle
        case 2: return .medium
        default: return .strong
        }
    }

    var body: some View {
        content
            .background(backgroundColor)
            .cornerRadius(.cornerRadiusMedium)
            .elevation(elevationStyle)
    }
}

// MARK: - Preview
#if DEBUG
struct ElevatedCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: .spacingLG) {
            ElevatedCard(depth: 1) {
                Text("Depth 1 - Subtle")
                    .padding(.paddingCard)
            }

            ElevatedCard(depth: 2) {
                Text("Depth 2 - Medium")
                    .padding(.paddingCard)
            }

            ElevatedCard(depth: 3) {
                Text("Depth 3 - Strong")
                    .padding(.paddingCard)
            }
        }
        .padding()
        .background(Color.adaptiveBackground)
    }
}
#endif
