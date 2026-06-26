import SwiftUI

/// 21th 风格按钮组件。零圆角、2px 边框、偏移阴影。
struct NeoButton: View {
    enum Style {
        case primary       // accent 蓝填充 + 白字
        case secondary     // panel 填充 + accent 蓝字 + 白色边框
        case destructive   // danger 红填充 + 白字
        case ghost         // 透明背景 + 文字
    }

    enum Size {
        case sm   // h:8 v:4, font:11
        case md   // h:10 v:6, font:12
        case lg   // h:14 v:8, font:13
    }

    let title: String
    var systemImage: String? = nil
    var style: Style = .secondary
    var size: Size = .md
    var isEnabled: Bool = true
    let action: () -> Void

    private var padding: (h: CGFloat, v: CGFloat) {
        switch size {
        case .sm: return (8, 4)
        case .md: return (10, 6)
        case .lg: return (14, 8)
        }
    }

    private var fontSize: CGFloat {
        switch size {
        case .sm: return 11
        case .md: return 12
        case .lg: return 13
        }
    }

    private var bgColor: Color {
        switch style {
        case .primary: return Theme.accent
        case .secondary: return Theme.panel
        case .destructive: return Theme.danger
        case .ghost: return .clear
        }
    }

    private var fgColor: Color {
        switch style {
        case .primary, .destructive: return .white
        case .secondary: return Theme.accent
        case .ghost: return Theme.textPrimary
        }
    }

    private var borderColor: Color {
        switch style {
        case .primary: return Theme.accent
        case .secondary: return Theme.border
        case .destructive: return Theme.danger
        case .ghost: return .clear
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xxxs) {
                if let icon = systemImage {
                    Image(systemName: icon)
                        .font(.system(size: fontSize - 1, weight: .semibold))
                }
                Text(title)
                    .font(FT.data(fontSize, weight: .semibold))
            }
            .lineLimit(1)
            .padding(.horizontal, padding.h)
            .padding(.vertical, padding.v)
            .background(bgColor)
            .foregroundStyle(fgColor)
            .overlay(
                Rectangle()
                    .stroke(borderColor, lineWidth: style == .ghost ? 0 : ShapeToken.borderWidth)
            )
            .neoShadow(style == .ghost ? .none : .small)
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
