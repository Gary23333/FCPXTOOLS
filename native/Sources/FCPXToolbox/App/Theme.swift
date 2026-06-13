import SwiftUI

/// 视觉规格沿用 V0_3_IMPLEMENTATION_SPEC.md 的配色与排版。
enum Theme {
    static let background = Color(hex: 0xF6F7F5)
    static let panel = Color(hex: 0xFFFFFF)
    static let line = Color(hex: 0xDADFDB)
    static let textPrimary = Color(hex: 0x202421)
    static let textSecondary = Color(hex: 0x68706B)
    static let accent = Color(hex: 0x237063)
    static let accentDark = Color(hex: 0x164C44)
    static let safe = Color(hex: 0x1F7A4D)
    static let warning = Color(hex: 0xA96B00)
    static let danger = Color(hex: 0xB33A2C)

    static func riskColor(_ risk: CleanRisk) -> Color {
        switch risk {
        case .safe: return safe
        case .confirm: return warning
        case .readOnly: return textSecondary
        }
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// 统一的卡片容器。
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.line, lineWidth: 1)
            )
    }
}
