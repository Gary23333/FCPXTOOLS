import SwiftUI

// MARK: - 21th Design System Tokens

/// 21th 设计系统色彩令牌，支持系统深色与浅色模式。
enum Theme {
    // MARK: Background
    static let background = Color.dynamicColor(light: Color(hex: 0xC5C9C9), dark: Color(hex: 0x0A0A0A))
    static let panel = Color.dynamicColor(light: Color(hex: 0xD8DADA), dark: Color(hex: 0x1A1A1A))
    static let sidebar = Color.dynamicColor(light: Color(hex: 0xD8DADA), dark: Color(hex: 0x1A1A1A))
    static let sidebarAccent = Color.dynamicColor(light: Color(hex: 0xC5C9C9), dark: Color(hex: 0x222222))

    // MARK: Border
    static let border = Color.dynamicColor(light: Color.white, dark: Color.white.opacity(0.15))

    // MARK: Text
    static let textPrimary = Color.dynamicColor(light: Color(hex: 0x111111), dark: Color(hex: 0xFFFFFF))
    static let textSecondary = Color.dynamicColor(light: Color(hex: 0x666666), dark: Color(hex: 0x888888))
    static let textMuted = Color.dynamicColor(light: Color(hex: 0x888888), dark: Color(hex: 0x555555))

    // MARK: Accent
    static let accent = Color(hex: 0x0040FF)
    static let accentHover = Color.dynamicColor(light: Color(hex: 0x0033CC), dark: Color(hex: 0x3366FF))

    // MARK: Status
    static let safe = Color.dynamicColor(light: Color(hex: 0x1A7A3A), dark: Color(hex: 0x22C55E))
    static let warning = Color.dynamicColor(light: Color(hex: 0xB45309), dark: Color(hex: 0xF59E0B))
    static let danger = Color.dynamicColor(light: Color(hex: 0xD73333), dark: Color(hex: 0xEF4444))

    // MARK: Chart (21th blue scale)
    static let chart1 = Color(hex: 0x0140FF)
    static let chart2 = Color(hex: 0x386AFF)
    static let chart3 = Color(hex: 0x6B90FF)
    static let chart4 = Color(hex: 0x94AFFF)
    static let chart5 = Color(hex: 0xBDCDFF)

    // MARK: Risk color (backward compat)
    static func riskColor(_ risk: CleanRisk) -> Color {
        switch risk {
        case .safe: return safe
        case .confirm: return warning
        case .readOnly: return textSecondary
        }
    }
}

// MARK: - Shape Tokens

enum ShapeToken {
    static let cornerRadius: CGFloat = 0
    static let borderWidth: CGFloat = 2
}

// MARK: - Shadow Tokens

enum NeoShadow {
    static let offset: CGFloat = 4
    static let color: Color = .black.opacity(0.25)
    static let radius: CGFloat = 0

    static func small(color: Color = NeoShadow.color) -> some ViewModifier {
        OffsetShadowModifier(offset: 3, color: color)
    }

    static func medium(color: Color = NeoShadow.color) -> some ViewModifier {
        OffsetShadowModifier(offset: 4, color: color)
    }
}

private struct OffsetShadowModifier: ViewModifier {
    let offset: CGFloat
    let color: Color

    func body(content: Content) -> some View {
        content.shadow(color: color, radius: 0, x: offset, y: offset)
    }
}

extension View {
    func neoShadow(_ level: ShadowLevel = .medium) -> some View {
        self.shadow(
            color: level == .none ? .clear : Color.black.opacity(0.25),
            radius: 0,
            x: level == .medium ? 4 : level == .small ? 2 : 0,
            y: level == .medium ? 4 : level == .small ? 2 : 0
        )
    }
}

enum ShadowLevel {
    case none, small, medium
}

// MARK: - Font Tokens

/// 21th 等宽字体令牌。优先使用 Geist Mono，回退到 Menlo。
enum FT {
    /// 大写标签 (section headers, badges)
    static func label(_ size: CGFloat = 10, weight: Font.Weight = .medium) -> Font {
        FontLoader.font(size: size, weight: weight)
    }

    /// 数据文本 (body, list rows, descriptions)
    static func data(_ size: CGFloat = 13, weight: Font.Weight = .regular) -> Font {
        FontLoader.font(size: size, weight: weight)
    }

    /// 页面标题
    static func title(_ size: CGFloat = 22, weight: Font.Weight = .bold) -> Font {
        FontLoader.font(size: size, weight: weight)
    }

    /// 大数字指标 (metric cards)
    static func metric(_ size: CGFloat = 28, weight: Font.Weight = .bold) -> Font {
        FontLoader.font(size: size, weight: weight)
    }

    /// 侧边栏品牌文字
    static func brand(_ size: CGFloat = 12, weight: Font.Weight = .bold) -> Font {
        FontLoader.font(size: size, weight: weight)
    }
}

// MARK: - App Info

/// 应用元信息，统一从 Info.plist 读取，避免版本号在多处硬编码。
enum AppInfo {
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.4.0"
    }

    /// 带 "V" 前缀的展示版本，如 "V0.4.0"。
    static var displayVersion: String { "V\(version)" }
}

// MARK: - Spacing Tokens

enum Spacing {
    static let xxxs: CGFloat = 4
    static let xxs: CGFloat = 8
    static let xs: CGFloat = 12
    static let sm: CGFloat = 16
    static let md: CGFloat = 20
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 40
}

// MARK: - Card (21th: zero radius + white border + offset shadow)

struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var shadowLevel: ShadowLevel = .medium

    var body: some View {
        content
            .background(Theme.panel)
            .overlay(
                Rectangle()
                    .stroke(Theme.border, lineWidth: ShapeToken.borderWidth)
            )
            .neoShadow(shadowLevel)
    }
}

// MARK: - Color Extensions (preserved)

extension Color {
    /// 基于 macOS NSColor appearance 动态生成自适应明暗的 Color。
    static func dynamicColor(light: Color, dark: Color) -> Color {
        return Color(NSColor(name: nil) { appearance in
            if appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua {
                return NSColor(dark)
            } else {
                return NSColor(light)
            }
        })
    }

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
