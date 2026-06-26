import SwiftUI
import AppKit

/// Geist Mono 字体加载器。
///
/// 字体文件通过 SwiftPM 资源打包，存放于 `Bundle.module`。若 bundled 字体
/// 不可用（注册失败或资源缺失），自动回退到系统等宽字体 (SF Mono)，
/// 而非比例字体，从而始终保持仪表盘等宽风格。
enum FontLoader {
    private static var registered = false

    /// bundled Geist Mono 是否注册成功且可用。
    private(set) static var available = false

    private static let faces = [
        "GeistMono-Regular",
        "GeistMono-Medium",
        "GeistMono-SemiBold",
        "GeistMono-Bold"
    ]

    /// 在 App 启动时调用，尝试注册 bundled Geist Mono 字体。幂等。
    static func registerFonts() {
        guard !registered else { return }
        registered = true

        var anyRegistered = false
        for name in faces {
            guard let url = Bundle.module.url(forResource: name, withExtension: "ttf")
                    ?? Bundle.module.url(forResource: name, withExtension: "otf"),
                  let provider = CGDataProvider(url: url as CFURL),
                  let font = CGFont(provider) else {
                continue
            }
            if CTFontManagerRegisterGraphicsFont(font, nil) {
                anyRegistered = true
            }
        }

        // 用真实的 PostScript 名称验证可用性（Regular face 即 "GeistMono-Regular"）。
        available = anyRegistered && NSFont(name: "GeistMono-Regular", size: 12) != nil
    }

    /// 返回指定字号与字重的字体。Geist Mono 可用时使用其对应字面，否则回退
    /// 到系统等宽字体（仍支持任意字重）。
    static func font(size: CGFloat, weight: Font.Weight) -> Font {
        if available {
            return .custom(geistFace(for: weight), size: size)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    private static func geistFace(for weight: Font.Weight) -> String {
        switch weight {
        case .bold, .heavy, .black:
            return "GeistMono-Bold"
        case .semibold:
            return "GeistMono-SemiBold"
        case .medium:
            return "GeistMono-Medium"
        default:
            return "GeistMono-Regular"
        }
    }
}
