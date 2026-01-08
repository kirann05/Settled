import SwiftUI

// MARK: - Badge Component
// Standalone badge for status labels and tags

struct Badge: View {
    let label: String
    var variant: BadgeVariant = .default
    var size: BadgeSize = .medium

    enum BadgeVariant {
        case `default`
        case success
        case warning
        case error
        case info

        var backgroundColor: Color {
            switch self {
            case .default: return .adaptiveDepth1
            case .success: return .feedbackSuccess.opacity(0.15)
            case .warning: return .feedbackWarning.opacity(0.15)
            case .error: return .feedbackError.opacity(0.15)
            case .info: return .feedbackInfo.opacity(0.15)
            }
        }

        var textColor: Color {
            switch self {
            case .default: return .textPrimary
            case .success: return .feedbackSuccess
            case .warning: return .feedbackWarning
            case .error: return .feedbackError
            case .info: return .feedbackInfo
            }
        }
    }

    enum BadgeSize {
        case small
        case medium
        case large

        var fontSize: Font {
            switch self {
            case .small: return .system(size: 10, weight: .semibold)
            case .medium: return .system(size: 12, weight: .semibold)
            case .large: return .system(size: 14, weight: .semibold)
            }
        }

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 2, leading: 6, bottom: 2, trailing: 6)
            case .medium: return EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
            case .large: return EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
            }
        }
    }

    var body: some View {
        Text(label)
            .font(size.fontSize)
            .foregroundColor(variant.textColor)
            .padding(size.padding)
            .background(variant.backgroundColor)
            .cornerRadius(.cornerRadiusSmall)
    }
}

// MARK: - Preview
#if DEBUG
struct Badge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: .spacingMD) {
            HStack(spacing: .spacingSM) {
                Badge(label: "Default", variant: .default)
                Badge(label: "Success", variant: .success)
                Badge(label: "Warning", variant: .warning)
            }

            HStack(spacing: .spacingSM) {
                Badge(label: "Error", variant: .error)
                Badge(label: "Info", variant: .info)
            }

            HStack(spacing: .spacingSM) {
                Badge(label: "Small", size: .small)
                Badge(label: "Medium", size: .medium)
                Badge(label: "Large", size: .large)
            }
        }
        .padding()
    }
}
#endif
