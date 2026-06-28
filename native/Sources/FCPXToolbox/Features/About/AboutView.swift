import SwiftUI

/// 关于软件窗口。
struct AboutView: View {
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.5.0"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var body: some View {
        VStack(spacing: Spacing.xl) {
            // App Logo
            Image(systemName: "sparkles")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(Theme.accent)
                .frame(width: 80, height: 80)
                .background(
                    Rectangle()
                        .fill(Theme.panel)
                        .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
                        .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)
                )

            // App Info
            VStack(spacing: Spacing.sm) {
                Text("FCPX 工具箱")
                    .font(FontFamily.heading(24))
                    .foregroundColor(Theme.textPrimary)

                Text("Version \(appVersion) (Build \(buildNumber))")
                    .font(FT.data())
                    .foregroundColor(Theme.textSecondary)
            }

            // Description
            Text("为 Final Cut Pro 用户准备的 macOS 原生工具箱。\n安全清理、高效归档、智能字幕与输出管理，一站式后期工作流辅助。")
                .font(FontFamily.bodyText(14))
                .multilineTextAlignment(.center)
                .foregroundColor(Theme.textPrimary)
                .padding(.horizontal, Spacing.lg)

            Divider()
                .padding(.horizontal, Spacing.lg)

            // Links & Copyright
            VStack(spacing: Spacing.sm) {
                HStack(spacing: Spacing.xl) {
                    Link("开源主页", destination: URL(string: "https://github.com/Gary23333/FCPXTOOLS")!)
                    Link("提报问题", destination: URL(string: "https://github.com/Gary23333/FCPXTOOLS/issues")!)
                    Link("许可协议", destination: URL(string: "https://opensource.org/licenses/MIT")!)
                }
                .font(FontFamily.bodyText(14))

                Text("Copyright © 2026 Gary. All rights reserved.")
                    .font(FontFamily.caption(12))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.top, Spacing.sm)
            }
        }
        .frame(width: 420, height: 380)
        .padding(Spacing.lg)
        .background(Theme.background)
        .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
        .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)
    }
}
