import SwiftUI

/// 21th 风格方角标签组件。替代 Capsule 标签。
struct NeoBadge: View {
    enum Style {
        case safe
        case warning
        case danger
        case neutral
        case accent
    }

    let text: String
    var style: Style = .neutral

    private var bgColor: Color {
        switch style {
        case .safe: return Theme.safe.opacity(0.15)
        case .warning: return Theme.warning.opacity(0.15)
        case .danger: return Theme.danger.opacity(0.15)
        case .neutral: return Theme.textSecondary.opacity(0.15)
        case .accent: return Theme.accent.opacity(0.15)
        }
    }

    private var fgColor: Color {
        switch style {
        case .safe: return Theme.safe
        case .warning: return Theme.warning
        case .danger: return Theme.danger
        case .neutral: return Theme.textSecondary
        case .accent: return Theme.accent
        }
    }

    var body: some View {
        Text(text)
            .font(FT.label(10, weight: .semibold))
            .foregroundStyle(fgColor)
            .padding(.horizontal, Spacing.xxs)
            .padding(.vertical, 2)
            .background(bgColor)
    }
}
