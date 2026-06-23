import SwiftUI

/// 工具箱顶层分区。
enum ToolSection: String, CaseIterable, Identifiable {
    case quickAccess = "快捷打开"
    case process = "进程管理"
    case cleanup = "清理助手"
    case templates = "模板库"
    case healthCheck = "健康检查"
    case archive = "归档管理"
    case subtitle = "快速字幕"
    case destination = "输出管理"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .quickAccess: return "bolt.horizontal.circle"
        case .process: return "activity"
        case .cleanup: return "sparkles"
        case .templates: return "square.grid.2x2"
        case .healthCheck: return "heart.text.square"
        case .archive: return "archivebox"
        case .subtitle: return "captions.bubble"
        case .destination: return "square.and.arrow.up.on.square"
        }
    }

    /// 侧边栏分组。
    var group: String {
        switch self {
        case .quickAccess, .process: return "快捷工具"
        case .cleanup, .templates, .healthCheck, .archive: return "资源管理"
        case .subtitle, .destination: return "创作辅助"
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var cleanupModel = CleanupViewModel()

    private var section: ToolSection {
        get { appState.selectedSection }
    }

    private var groupedSections: [(String, [ToolSection])] {
        let order: [String] = ["快捷工具", "资源管理", "创作辅助"]
        return order.map { group in
            (group, ToolSection.allCases.filter { $0.group == group })
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 180, ideal: 200, max: 260)
        } detail: {
            detailView
        }
        .navigationTitle("FCPX 工具箱")
    }

    // MARK: - 侧边栏

    private var sidebar: some View {
        List(selection: Binding(
            get: { appState.selectedSection },
            set: { if let s = $0 { appState.selectedSection = s } }
        )) {
            ForEach(groupedSections, id: \.0) { group, sections in
                Section(group) {
                    ForEach(sections) { item in
                        sidebarRow(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(_ item: ToolSection) -> some View {
        Label {
            Text(item.rawValue)
                .font(.system(size: 13, weight: .medium))
        } icon: {
            Image(systemName: item.systemImage)
                .font(.system(size: 14))
                .foregroundStyle(section == item ? Theme.accent : Theme.textSecondary)
                .frame(width: 20)
        }
        .tag(item)
        .padding(.vertical, 3)
    }

    // MARK: - 详情视图

    @ViewBuilder
    private var detailView: some View {
        switch section {
        case .quickAccess:
            QuickAccessView()
        case .process:
            ProcessManagerView()
        case .cleanup:
            CleanupView(model: cleanupModel)
        case .templates:
            TemplateLibraryView()
        case .healthCheck:
            HealthCheckView()
        case .archive:
            ArchiveManagerView()
        case .subtitle:
            SubtitleToolView()
        case .destination:
            DestinationManagerView()
        }
    }
}
