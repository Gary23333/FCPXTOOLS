import SwiftUI

/// 工具箱顶层分区。模板库（含字幕=Titles 分类）在阶段 2 接入。
enum ToolSection: String, CaseIterable, Identifiable {
    case quickAccess = "快捷打开"
    case process = "进程管理"
    case cleanup = "清理"
    case templates = "模板库"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .quickAccess: return "bolt.horizontal.circle"
        case .process: return "activity"
        case .cleanup: return "sparkles"
        case .templates: return "square.grid.2x2"
        }
    }
}

struct RootView: View {
    @State private var section: ToolSection = .cleanup
    @StateObject private var cleanupModel = CleanupViewModel()

    var body: some View {
        NavigationSplitView {
            List(ToolSection.allCases, selection: $section) { item in
                Label(item.rawValue, systemImage: item.systemImage)
                    .tag(item)
            }
            .navigationSplitViewColumnWidth(min: 168, ideal: 188, max: 240)
            .listStyle(.sidebar)
        } detail: {
            switch section {
            case .quickAccess:
                QuickAccessView()
            case .process:
                ProcessManagerView()
            case .cleanup:
                CleanupView(model: cleanupModel)
            case .templates:
                TemplateLibraryView()
            }
        }
        .navigationTitle("FCPX 工具箱")
    }
}
