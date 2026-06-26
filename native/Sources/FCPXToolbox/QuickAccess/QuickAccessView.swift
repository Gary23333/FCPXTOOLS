import SwiftUI

/// 快捷打开入口的数据模型。
struct QuickAccessEntry: Identifiable {
    let id = UUID()
    let icon: String
    let name: String
    let path: String
    let isApplication: Bool
    /// 在 Finder 中需要高亮选中的文件名（可选）。
    let highlightFile: String?
}

@MainActor
final class QuickAccessViewModel: ObservableObject {
    @Published private(set) var entries: [QuickAccessEntry] = []
    @Published private(set) var existence: [String: Bool] = [:]
    @Published private(set) var lastRefresh: Date = .distantPast

    init() {
        entries = Self.makeEntries()
        refresh()
    }

    private static func makeEntries() -> [QuickAccessEntry] {
        let home = NSHomeDirectory()
        return [
            QuickAccessEntry(icon: "film",
                             name: "用户影片目录",
                             path: "\(home)/Movies",
                             isApplication: false, highlightFile: nil),
            QuickAccessEntry(icon: "square.stack.3d.up",
                             name: "Motion 模板目录",
                             path: "\(home)/Movies/Motion Templates.localized",
                             isApplication: false, highlightFile: nil),
            QuickAccessEntry(icon: "gearshape.2",
                             name: "FCPX 系统支持",
                             path: "/Library/Application Support/Final Cut Pro",
                             isApplication: false, highlightFile: nil),
            QuickAccessEntry(icon: "person.crop.square",
                             name: "FCPX 用户支持",
                             path: "\(home)/Library/Application Support/Final Cut Pro",
                             isApplication: false, highlightFile: nil),
            QuickAccessEntry(icon: "slider.horizontal.3",
                             name: "FCPX 偏好设置",
                             path: "\(home)/Library/Preferences",
                             isApplication: false, highlightFile: "com.apple.FinalCut.plist"),
            QuickAccessEntry(icon: "internaldrive",
                             name: "FCPX 缓存目录",
                             path: "\(home)/Library/Caches/Final Cut Pro",
                             isApplication: false, highlightFile: nil),
            QuickAccessEntry(icon: "wrench.adjustable",
                             name: "ProApps 设置",
                             path: "\(home)/Library/Application Support/ProApps",
                             isApplication: false, highlightFile: nil),
            QuickAccessEntry(icon: "square.and.arrow.up",
                             name: "FCPX 输出目标",
                             path: "\(home)/Library/Preferences/Final Cut Pro Destinations",
                             isApplication: false, highlightFile: nil),
            QuickAccessEntry(icon: "play.rectangle.fill",
                             name: "启动 Final Cut Pro",
                             path: "/Applications/Final Cut Pro.app",
                             isApplication: true, highlightFile: nil),
        ]
    }

    /// 重新检查所有入口的存在状态。
    func refresh() {
        var map: [String: Bool] = [:]
        for entry in entries {
            map[entry.path] = FileManager.default.fileExists(atPath: entry.path)
        }
        existence = map
        lastRefresh = Date()
    }

    func exists(_ entry: QuickAccessEntry) -> Bool {
        existence[entry.path] ?? false
    }

    /// 打开入口：应用则启动，目录则在 Finder 中打开（可高亮指定文件）。
    func open(_ entry: QuickAccessEntry) {
        let url = URL(fileURLWithPath: entry.path)
        if entry.isApplication {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        } else if let highlight = entry.highlightFile {
            // 偏好设置目录：在 Finder 中定位并高亮指定 plist。
            let fileURL = url.appendingPathComponent(highlight)
            NSWorkspace.shared.activateFileViewerSelecting([fileURL])
        } else {
            NSWorkspace.shared.open(url)
        }
    }
}

struct QuickAccessView: View {
    @StateObject private var model = QuickAccessViewModel()

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 380), spacing: Spacing.xxs)]

    var body: some View {
        VStack(spacing: Spacing.xs) {
            header
            ScrollView {
                LazyVGrid(columns: columns, spacing: Spacing.xxs) {
                    ForEach(model.entries) { entry in
                        entryCard(entry)
                    }
                }
                .padding(.bottom, Spacing.xxs)
            }
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - 顶部标题

    private var header: some View {
        HStack(spacing: Spacing.xxs) {
            NeoSectionHeader(
                systemImage: "bolt.horizontal.circle",
                title: "快捷打开",
                subtitle: "一键打开 FCPX 常用目录或启动应用。不存在的路径会显示为禁用状态。"
            )
            Spacer()
            NeoButton(title: "刷新", systemImage: "arrow.clockwise", style: .secondary, size: .sm) {
                model.refresh()
            }
        }
    }

    // MARK: - 入口卡片

    private func entryCard(_ entry: QuickAccessEntry) -> some View {
        let exists = model.exists(entry)
        return Card {
            HStack(alignment: .top, spacing: Spacing.xxs) {
                Image(systemName: entry.icon)
                    .font(FT.title(22))
                    .foregroundStyle(exists ? Theme.accent : Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(exists ? Theme.accent.opacity(0.1) : Theme.background)
                    .clipShape(Rectangle())

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    HStack(spacing: Spacing.xxxs) {
                        Text(entry.name)
                            .font(FT.data(14))
                            .foregroundStyle(Theme.textPrimary)
                        if !exists {
                            NeoBadge(text: "不存在", style: .neutral)
                        }
                    }
                    Text(entry.path)
                        .font(FT.label(11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if let highlight = entry.highlightFile {
                        Text("高亮：\(highlight)")
                            .font(FT.label(10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: Spacing.xxxs)

                NeoButton(
                    title: entry.isApplication ? "启动应用" : "在 Finder 中打开",
                    systemImage: entry.isApplication ? "play.fill" : "folder",
                    style: entry.isApplication ? .primary : .secondary,
                    size: .sm,
                    isEnabled: exists
                ) {
                    model.open(entry)
                }
            }
            .padding(Spacing.xxs)
            .opacity(exists ? 1 : 0.6)
        }
    }
}
