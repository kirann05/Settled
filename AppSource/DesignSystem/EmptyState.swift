import SwiftUI

// MARK: - Empty State Component
// Reusable empty state UI with icon, message, and action

struct EmptyState: View {
    let icon: String
    let heading: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: .spacingLG) {
            // Icon
            Image(systemName: icon)
                .font(.system(size: 64, weight: .light))
                .foregroundColor(.textTertiary)

            // Text Content
            VStack(spacing: .spacingSM) {
                Text(heading)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(.system(size: 16))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, .spacingXL)

            // Optional Action Button
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, .spacingXL)
                        .padding(.vertical, .spacingMD)
                        .background(Color.brandPrimary)
                        .cornerRadius(.cornerRadiusButton)
                }
                .padding(.top, .spacingSM)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.paddingCard)
    }
}

// MARK: - Preview
#if DEBUG
struct EmptyState_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyState(
                icon: "doc.text.magnifyingglass",
                heading: "No Bills Yet",
                message: "Create your first bill to start tracking shared expenses with friends"
            )

            EmptyState(
                icon: "tray",
                heading: "No Transaction History",
                message: "Your transaction history will appear here once you start creating bills",
                actionTitle: "Create Bill",
                action: { print("Create tapped") }
            )
        }
    }
}
#endif
