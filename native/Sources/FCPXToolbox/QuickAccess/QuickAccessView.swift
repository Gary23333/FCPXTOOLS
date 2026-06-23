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

    private let columns = [GridItem(.adaptive(minimum: 300, maximum: 380), spacing: 12)]

    var body: some View {
        VStack(spacing: 14) {
            header
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.entries) { entry in
                        entryCard(entry)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    // MARK: - 顶部标题

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "bolt.horizontal.circle")
                .font(.system(size: 26))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("快捷打开")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("一键打开 FCPX 常用目录或启动应用。不存在的路径会显示为禁用状态。")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            refreshButton
        }
    }

    private var refreshButton: some View {
        Button {
            model.refresh()
        } label: {
            Label("刷新", systemImage: "arrow.clockwise")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Theme.panel)
                .foregroundStyle(Theme.accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Theme.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 入口卡片

    private func entryCard(_ entry: QuickAccessEntry) -> some View {
        let exists = model.exists(entry)
        return Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: entry.icon)
                    .font(.system(size: 22))
                    .foregroundStyle(exists ? Theme.accent : Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(exists ? Theme.accent.opacity(0.1) : Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(entry.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if !exists {
                            Text("不存在")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Theme.textSecondary.opacity(0.14))
                                .foregroundStyle(Theme.textSecondary)
                                .clipShape(Capsule())
                        }
                    }
                    Text(entry.path)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                    if let highlight = entry.highlightFile {
                        Text("高亮：\(highlight)")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer(minLength: 4)

                openButton(entry, exists: exists)
            }
            .padding(12)
            .opacity(exists ? 1 : 0.6)
        }
    }

    private func openButton(_ entry: QuickAccessEntry, exists: Bool) -> some View {
        let title = entry.isApplication ? "启动应用" : "在 Finder 中打开"
        let icon = entry.isApplication ? "play.fill" : "folder"
        return Button {
            model.open(entry)
        } label: {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(entry.isApplication ? Theme.accent : Theme.panel)
                .foregroundStyle(entry.isApplication ? Color.white : Theme.accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(entry.isApplication ? Theme.accent : Theme.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .opacity(exists ? 1 : 0.42)
        }
        .buttonStyle(.plain)
        .disabled(!exists)
    }
}
