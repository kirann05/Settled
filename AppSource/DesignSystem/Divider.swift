import SwiftUI

// MARK: - Divider Component
// Lightweight separator lines with customization

struct StyledDivider: View {
    var thickness: CGFloat = 1
    var color: Color = .adaptiveBorder
    var paddingVertical: CGFloat = .spacingMD
    var paddingHorizontal: CGFloat = 0

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: thickness)
            .padding(.vertical, paddingVertical)
            .padding(.horizontal, paddingHorizontal)
    }
}

struct VerticalDivider: View {
    var thickness: CGFloat = 1
    var color: Color = .adaptiveBorder
    var height: CGFloat? = nil

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: thickness, height: height)
    }
}

// MARK: - Preview
#if DEBUG
struct Divider_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: .spacingLG) {
            Text("Content above")
            StyledDivider()
            Text("Content below")

            HStack {
                Text("Left")
                VerticalDivider(height: 40)
                Text("Right")
            }
        }
        .padding()
    }
}
#endif
