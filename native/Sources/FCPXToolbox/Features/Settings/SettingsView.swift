import SwiftUI

/// 偏好设置视图。
struct SettingsView: View {
    @StateObject private var prefs = AppPreferences.shared
    @State private var selectedTab = "general"

    var body: some View {
        VStack(spacing: 0) {
            // 自定义 Tab 栏
            HStack(spacing: Spacing.sm) {
                NeoButton(title: "通用", systemImage: "gearshape", style: .ghost, size: .md) {
                    selectedTab = "general"
                }
                .background(selectedTab == "general" ? Theme.accent.opacity(0.15) : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(selectedTab == "general" ? Theme.accent : Theme.border, lineWidth: ShapeToken.borderWidth)
                )

                NeoButton(title: "外观与语言", systemImage: "paintpalette", style: .ghost, size: .md) {
                    selectedTab = "appearance"
                }
                .background(selectedTab == "appearance" ? Theme.accent.opacity(0.15) : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(selectedTab == "appearance" ? Theme.accent : Theme.border, lineWidth: ShapeToken.borderWidth)
                )

                NeoButton(title: "高级", systemImage: "slider.horizontal.3", style: .ghost, size: .md) {
                    selectedTab = "advanced"
                }
                .background(selectedTab == "advanced" ? Theme.accent.opacity(0.15) : Color.clear)
                .overlay(
                    Rectangle()
                        .stroke(selectedTab == "advanced" ? Theme.accent : Theme.border, lineWidth: ShapeToken.borderWidth)
                )

                Spacer()
            }
            .padding(Spacing.lg)

            Divider()

            // 内容区域
            Group {
                switch selectedTab {
                case "general":
                    generalTab
                case "appearance":
                    appearanceTab
                case "advanced":
                    advancedTab
                default:
                    generalTab
                }
            }
        }
        .frame(width: 500, height: 350)
        .padding(Spacing.lg)
        .onAppear {
            prefs.load()
        }
    }

    // MARK: - 通用设置页

    private var generalTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // 默认扫描目录
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("默认扫描目录")
                        .font(FT.title())
                    HStack {
                        Text(prefs.defaultScanPath ?? "未设置（每次手动选择）")
                            .foregroundStyle(Theme.textSecondary)
                            .font(FT.data())
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        NeoButton(title: "浏览...", style: .secondary, size: .sm) {
                            chooseDefaultScanPath()
                        }
                    }
                }
                .padding(Spacing.lg)
                .background(Theme.panel)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
                .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)

                // 清理缓存前二次确认
                Toggle("清理缓存前二次确认", isOn: $prefs.confirmBeforeClean)
                    .toggleStyle(.checkbox)
                    .font(FT.data())
                    .foregroundStyle(Theme.textPrimary)
                    .padding(Spacing.lg)
                    .background(Theme.panel)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
                    .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)

                // 启动默认加载版块
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("启动默认加载版块")
                        .font(FT.data())
                        .foregroundStyle(Theme.textPrimary)
                    Picker("启动默认加载版块", selection: $prefs.startupSection) {
                        ForEach(["清理助手", "模板库", "快捷打开", "健康检查", "归档管理", "快速字幕", "输出管理"], id: \.self) { section in
                            Text(section).tag(section)
                        }
                    }
                    .font(FT.data())
                }
                .padding(Spacing.lg)
                .background(Theme.panel)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
                .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)
            }
        }
    }

    // MARK: - 外观与语言设置页

    private var appearanceTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // 外观模式
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("外观模式")
                        .font(FT.data())
                        .foregroundStyle(Theme.textPrimary)
                    Picker("外观模式", selection: $prefs.appearanceMode) {
                        Text("跟随系统").tag(AppearanceMode.system)
                        Text("浅色模式").tag(AppearanceMode.light)
                        Text("深色模式").tag(AppearanceMode.dark)
                    }
                    .pickerStyle(.radioGroup)
                    .font(FT.data())
                    .horizontalRadioGroupLayout()
                }
                .padding(Spacing.lg)
                .background(Theme.panel)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
                .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)

                // 语言
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("语言 (Language)")
                        .font(FT.data())
                        .foregroundStyle(Theme.textPrimary)
                    Picker("语言 (Language)", selection: $prefs.language) {
                        Text("跟随系统 (System)").tag("system")
                        Text("简体中文").tag("zh-Hans")
                        Text("English").tag("en")
                    }
                    .font(FT.data())
                }
                .padding(Spacing.lg)
                .background(Theme.panel)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
                .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)
            }
        }
    }

    // MARK: - 高级设置页

    private var advancedTab: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                // 自动检查更新
                Toggle("自动检查更新", isOn: $prefs.checkUpdatesAutomatically)
                    .toggleStyle(.checkbox)
                    .font(FT.data())
                    .foregroundStyle(Theme.textPrimary)
                    .padding(Spacing.lg)
                    .background(Theme.panel)
                    .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
                    .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)

                // 磁盘空间不足警报阈值
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("磁盘空间不足警报阈值 (GB)")
                        .font(FT.data())
                        .foregroundStyle(Theme.textPrimary)
                    Slider(value: $prefs.warnFreeSpaceBelowGB, in: 5...50, step: 5) {
                        Text("容量限制")
                    } minimumValueLabel: {
                        Text("5G")
                            .font(FT.label())
                    } maximumValueLabel: {
                        Text("50G")
                            .font(FT.label())
                    }
                    Text("当前阈值: \(Int(prefs.warnFreeSpaceBelowGB)) GB (磁盘剩余容量低于此值时将弹出警告)")
                        .font(FT.label())
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(Spacing.lg)
                .background(Theme.panel)
                .overlay(Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth))
                .shadow(color: Color.black.opacity(0.25), radius: 0, x: 4, y: 4)

                // 恢复出厂设置
                HStack {
                    Spacer()
                    NeoButton(title: "恢复出厂设置", style: .destructive, size: .md) {
                        prefs.resetToDefaults()
                    }
                }
            }
        }
    }

    // MARK: - 文件目录选择器

    private func chooseDefaultScanPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择目录"
        if panel.runModal() == .OK, let url = panel.url {
            prefs.defaultScanPath = url.path
        }
    }
}
