import SwiftUI
import AppKit

/// 首次启动的欢迎与权限引导界面。
struct OnboardingView: View {
    @State private var currentStep = 0
    @StateObject private var prefs = AppPreferences.shared

    var onDismiss: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            // 顶部长条进度指示
            HStack(spacing: Spacing.sm) {
                ForEach(0..<3) { idx in
                    Rectangle()
                        .fill(idx <= currentStep ? Theme.accent : Theme.textSecondary.opacity(0.3))
                        .frame(height: 4)
                        .animation(.spring(), value: currentStep)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, Spacing.xl)

            // 内容区域
            TabView(selection: $currentStep) {
                stepWelcome.tag(0)
                stepSecurity.tag(1)
                stepFDA.tag(2)
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.82), value: currentStep)

            Divider()

            // 底部控制按钮
            HStack {
                if currentStep > 0 {
                    NeoButton(title: "上一步", style: .ghost, size: .sm) {
                        currentStep -= 1
                    }
                }

                Spacer()

                if currentStep < 2 {
                    NeoButton(title: "下一步", style: .primary, size: .lg) {
                        currentStep += 1
                    }
                } else {
                    NeoButton(title: "开始使用", style: .primary, size: .lg) {
                        prefs.hasCompletedOnboarding = true
                        onDismiss()
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.vertical, Spacing.xl)
            .background(Theme.panel)
        }
        .frame(width: 600, height: 480)
        .background(Theme.background)
    }

    // MARK: - 步骤 1：欢迎与功能介绍

    private var stepWelcome: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "sparkles")
                .font(FT.metric())
                .foregroundColor(Theme.accent)
                .padding(.top, Spacing.xl)

            VStack(spacing: Spacing.sm) {
                Text("欢迎使用 FCPX 工具箱")
                    .font(FT.title())
                    .foregroundColor(Theme.textPrimary)

                Text("专为 Final Cut Pro 设计的原生 macOS 生产力管家")
                    .font(FT.data())
                    .foregroundColor(Theme.textSecondary)
            }

            // 模块介绍卡片
            VStack(alignment: .leading, spacing: Spacing.md) {
                featureRow(icon: "sparkles", title: "安全清理缓存", desc: "精准分类渲染、代理等无用缓存，一键安全移至废纸篓。")
                featureRow(icon: "square.grid.2x2", title: "模板与插件管理", desc: "可视化整理 Motion Templates 模板，支持一键切换 FxPlug 插件状态。")
                featureRow(icon: "captions.bubble", title: "快速字幕与输出", desc: "依托原生 ASR 字幕听写生成 SRT 文本，自定义配置输出目标。")
            }
            .padding(Spacing.lg)
            .background(Theme.panel)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
            .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - 步骤 2：安全红线说明

    private var stepSecurity: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "shield.checkerboard")
                .font(FT.metric())
                .foregroundColor(Theme.safe)
                .padding(.top, Spacing.xl)

            VStack(spacing: Spacing.sm) {
                Text("数据安全是我们的生命线")
                    .font(FT.title())
                    .foregroundColor(Theme.textPrimary)

                Text("尊重用户隐私与每一位后期工作者的珍贵素材")
                    .font(FT.data())
                    .foregroundColor(Theme.textSecondary)
            }

            VStack(alignment: .leading, spacing: 14) {
                safetyBullet(title: "绝不触碰原始素材 (Original Media)", desc: "我们只会扫描由 FCPX 渲染生成的临时缓存，你的原素材保持只读，永不删除。")
                safetyBullet(title: "保留一次反悔机会 (Trash Bin)", desc: "所有的清理动作均通过系统废纸篓进行，删除后仍可前往废纸篓一键还原。")
                safetyBullet(title: "100% 本地运行", desc: "数据不上传、无需联网，ASR 语音转录字幕等功能全部由 macOS 离线神经网络完成。")
            }
            .padding(Spacing.lg)
            .background(Theme.panel)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
            .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)
            .padding(.horizontal, 40)
        }
    }

    // MARK: - 步骤 3：完全磁盘访问权限 FDA 引导

    private var stepFDA: some View {
        VStack(spacing: Spacing.xl) {
            Image(systemName: "lock.shield.fill")
                .font(FT.metric())
                .foregroundColor(Theme.warning)
                .padding(.top, Spacing.sm)

            VStack(spacing: Spacing.sm) {
                Text("授权完全磁盘访问权限")
                    .font(FT.title())
                    .foregroundColor(Theme.textPrimary)

                Text("由于 macOS 安全隔离机制，清理与管理外置素材磁盘需要此权限")
                    .font(FT.data())
                    .foregroundColor(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            // 步骤引导
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("如何授权？")
                    .font(FT.data())
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)

                stepItem(num: "1", text: "点击下方「打开隐私设置」按钮。")
                stepItem(num: "2", text: "在系统设置列表中找到并解锁「完全磁盘访问权限」。")
                stepItem(num: "3", text: "将「FCPX 工具箱」旁的开关切换为 开启 状态。")
            }
            .padding(Spacing.lg)
            .background(Theme.panel)
            .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
            .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)
            .padding(.horizontal, 40)

            NeoButton(title: "打开「系统设置」隐私面板", systemImage: "arrow.up.forward.app", style: .secondary, size: .md) {
                openSystemPreferencesFDA()
            }
            .padding(.top, Spacing.sm)
        }
    }

    // MARK: - 辅助子视图

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: icon)
                .font(FT.data())
                .foregroundColor(Theme.accent)
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(FT.data())
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
                Text(desc)
                    .font(FT.label())
                    .foregroundColor(Theme.textSecondary)
            }
        }
    }

    private func safetyBullet(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(Theme.safe)
                    .font(FT.data())
                Text(title)
                    .font(FT.data())
                    .fontWeight(.bold)
                    .foregroundColor(Theme.textPrimary)
            }
            Text(desc)
                .font(FT.label())
                .foregroundColor(Theme.textSecondary)
                .padding(.leading, 19)
        }
    }

    private func stepItem(num: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(num)
                .font(FT.label())
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(Rectangle().fill(Theme.accent))
                .padding(.top, 1)

            Text(text)
                .font(FT.label())
                .foregroundColor(Theme.textPrimary)
        }
    }

    // MARK: - 辅助逻辑

    private func openSystemPreferencesFDA() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }
}
