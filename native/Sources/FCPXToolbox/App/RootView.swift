import SwiftUI

/// 工具箱顶层分区。
enum ToolSection: String, CaseIterable, Identifiable {
    case quickAccess = "快捷打开"
    case cleanup = "清理助手"
    case templates = "模板库"
    case plugins = "插件管理"
    case color = "色彩管理"
    case shortcuts = "快捷键管理"
    case healthCheck = "健康检查"
    case archive = "归档管理"
    case subtitle = "快速字幕"
    case destination = "输出管理"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .quickAccess: return "bolt.horizontal.circle"
        case .cleanup: return "sparkles"
        case .templates: return "square.grid.2x2"
        case .plugins: return "puzzlepiece"
        case .color: return "paintpalette"
        case .shortcuts: return "keyboard"
        case .healthCheck: return "heart.text.square"
        case .archive: return "archivebox"
        case .subtitle: return "captions.bubble"
        case .destination: return "square.and.arrow.up.on.square"
        }
    }

    /// 侧边栏分组。
    var group: String {
        switch self {
        case .quickAccess: return "快捷工具"
        case .cleanup, .templates, .plugins, .color, .shortcuts, .healthCheck, .archive: return "资源管理"
        case .subtitle, .destination: return "创作辅助"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var cleanupModel = CleanupViewModel()
    @StateObject private var processModel = ProcessManagerViewModel()
    @StateObject private var healthCheckModel = HealthCheckViewModel()
    @StateObject private var archiveModel = ArchiveManagerViewModel()
    @StateObject private var templateModel = TemplateLibraryViewModel()

    @State private var showingOnboarding = false
    @State private var showingProcessPopover = false

    private var section: ToolSection {
        get { appState.selectedSection }
    }

    var body: some View {
        HStack(spacing: 0) {
            // 21th sidebar
            NeoSidebar(selection: Binding(
                get: { appState.selectedSection },
                set: { appState.selectedSection = $0 }
            ))
            .frame(width: 200)
            .overlay(
                Rectangle()
                    .stroke(Theme.border, lineWidth: ShapeToken.borderWidth)
            )

            // Main content
            VStack(spacing: 0) {
                detailView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomStatusBar
            }
        }
        .background(Theme.background)
        .sheet(isPresented: $showingOnboarding) {
            OnboardingView {
                showingOnboarding = false
            }
        }
        .onAppear {
            FontLoader.registerFonts()
            if !AppPreferences.shared.hasCompletedOnboarding {
                showingOnboarding = true
            }
        }
    }

    // MARK: - 详情视图

    @ViewBuilder
    private var detailView: some View {
        switch section {
        case .quickAccess:
            QuickAccessView()
        case .cleanup:
            CleanupView(model: cleanupModel)
        case .templates:
            TemplateLibraryView(model: templateModel)
        case .plugins:
            PluginManagerView()
        case .color:
            ColorManagerView()
        case .shortcuts:
            ShortcutManagerView()
        case .healthCheck:
            HealthCheckView(model: healthCheckModel)
        case .archive:
            ArchiveManagerView(model: archiveModel)
        case .subtitle:
            SubtitleToolView()
        case .destination:
            DestinationManagerView()
        }
    }

    // MARK: - 全局状态栏

    private var bottomStatusBar: some View {
        HStack {
            HStack(spacing: Spacing.xxs) {
                Circle()
                    .fill(processModel.isRunning ? Theme.safe : Theme.textSecondary)
                    .frame(width: 6, height: 6)
                Text(processModel.isRunning ? "FCPX 运行中" : "FCPX 未运行")
                    .font(FT.label(11))
                    .foregroundStyle(Theme.textPrimary)

                if processModel.isRunning {
                    Text("· MEM: \(DisplayFormat.byteString(processModel.residentBytes))")
                        .font(FT.label(10))
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 5)
            .background(Theme.panel)
            .overlay(
                Rectangle()
                    .stroke(Theme.border, lineWidth: 1)
            )
            .onTapGesture {
                showingProcessPopover.toggle()
            }
            .popover(isPresented: $showingProcessPopover, arrowEdge: .top) {
                ProcessManagerView(model: processModel)
                    .frame(width: 320, height: 260)
            }

            Spacer()

            Text("FCPX TOOLBOX \(AppInfo.displayVersion)")
                .font(FT.label(10))
                .foregroundStyle(Theme.textMuted)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xxs)
        .background(Theme.panel)
        .overlay(
            Rectangle()
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}
