import SwiftUI

/// 桥接现有 FCPXScanner / FCPXCleanerCore 的同步回调到 SwiftUI 状态。
/// 扫描与清理放后台队列，结果回主线程，UI 不阻塞、可取消。
@MainActor
final class CleanupViewModel: ObservableObject {
    enum Phase: Equatable {
        case empty
        case scanning
        case ready
        case cleaning
    }

    @Published var phase: Phase = .empty
    @Published var rootURL: URL?
    @Published var projects: [ResourceItem] = []
    @Published var selectedProjectID: ResourceItem.ID?

    // 分页：大目录可能扫出很多资源库/项目，列表分页渲染避免卡顿。
    private let pageSize = 60
    @Published private(set) var displayLimit = 60
    var visibleProjects: [ResourceItem] { Array(projects.prefix(displayLimit)) }
    var canLoadMore: Bool { displayLimit < projects.count }

    func loadMoreIfNeeded(currentItem: ResourceItem) {
        guard canLoadMore else { return }
        if let idx = visibleProjects.firstIndex(where: { $0.id == currentItem.id }),
           idx >= visibleProjects.count - 8 {
            displayLimit += pageSize
        }
    }

    @Published var statusText = "选择包含 Final Cut Pro 资源库的目录开始扫描"
    @Published var progressText = ""
    @Published var progressValue = 0.0
    @Published var issues: [ScanIssue] = []

    @Published var lastResult: CleanResult?

    private let scanner = FCPXScanner()
    private let cleaner = FCPXCleanerCore()

    // 选择状态保存在 CacheGroup（引用类型）上；用 revision 触发刷新。
    @Published private(set) var revision = 0
    private func bumpRevision() { revision &+= 1 }

    var selectedProject: ResourceItem? {
        guard let id = selectedProjectID else { return projects.first }
        return projects.first { $0.id == id } ?? projects.first
    }

    var totalBytes: Int64 { projects.reduce(0) { $0 + $1.totalBytes } }
    var cleanableBytes: Int64 { projects.reduce(0) { $0 + $1.cleanableBytes } }
    var selectedBytes: Int64 { projects.reduce(0) { $0 + $1.selectedBytes } }

    var isBusy: Bool { phase == .scanning || phase == .cleaning }
    var canClean: Bool { !isBusy && selectedBytes > 0 }
    var canRescan: Bool { !isBusy && rootURL != nil }
    var canSelectSafe: Bool { !isBusy && !projects.isEmpty }

    // MARK: - 目录选择

    func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "扫描"
        if panel.runModal() == .OK, let url = panel.url {
            rootURL = url
            startScan(url)
        }
    }

    func rescan() {
        guard let rootURL else { return }
        startScan(rootURL)
    }

    func stopScan() {
        scanner.cancel()
        statusText = "正在停止扫描…"
    }

    // MARK: - 扫描

    private func startScan(_ url: URL) {
        phase = .scanning
        projects = []
        displayLimit = pageSize
        selectedProjectID = nil
        issues = []
        lastResult = nil
        statusText = "扫描中"
        progressText = ""
        progressValue = 0.08

        Task.detached(priority: .userInitiated) { [scanner] in
            let result = scanner.scan(root: url) { progress in
                Task { @MainActor in
                    self.progressText = "目录 \(progress.scannedDirectories) · 文件 \(progress.scannedFiles) · 发现 \(progress.discoveredProjects) · 可清理 \(DisplayFormat.byteString(progress.cleanableBytes))"
                    self.progressValue = progress.isCancelled ? 0 : min(0.95, self.progressValue + 0.01)
                }
            } projectFound: { project in
                Task { @MainActor in
                    self.projects.append(project)
                    self.projects.sort { $0.cleanableBytes > $1.cleanableBytes }
                    if self.selectedProjectID == nil {
                        self.selectedProjectID = self.projects.first?.id
                    }
                }
            }

            await MainActor.run {
                self.phase = .ready
                self.projects = result.projects
                self.selectedProjectID = result.projects.first?.id
                self.issues = result.issues
                self.progressValue = 1
                self.statusText = result.issues.isEmpty
                    ? String(format: "扫描完成，用时 %.1fs，共 %d 个资源库/项目", result.duration, result.projects.count)
                    : "扫描完成，\(result.projects.count) 个资源库/项目，\(result.issues.count) 个问题"
            }
        }
    }

    // MARK: - 选择

    func toggleGroup(_ group: CacheGroup) {
        guard group.canClean else { return }
        group.isSelected.toggle()
        bumpRevision()
    }

    func toggleProject(_ project: ResourceItem) {
        let shouldSelect = project.selectedBytes == 0
        for group in project.cacheGroups {
            group.isSelected = shouldSelect && group.canClean && group.risk == .safe
        }
        bumpRevision()
    }

    func selectAllSafe() {
        for project in projects {
            for group in project.cacheGroups {
                group.isSelected = group.risk == .safe && group.bytes > 0
            }
        }
        bumpRevision()
    }

    // MARK: - 清理

    /// 返回确认弹窗所需信息；nil 表示无可清理项。
    func cleanSummary() -> (count: Int, bytes: Int64, riskyTitles: [String])? {
        let targets = projects.flatMap(\.selectedTargets)
        guard !targets.isEmpty else { return nil }
        let risky = projects.flatMap(\.cacheGroups)
            .filter { $0.isSelected && $0.risk == .confirm }
            .map(\.title)
        return (targets.count, selectedBytes, Array(Set(risky)).sorted())
    }

    func performClean() {
        let targets = projects.flatMap(\.selectedTargets)
        guard !targets.isEmpty else { return }

        phase = .cleaning
        statusText = "清理中"
        progressValue = 0

        Task.detached(priority: .userInitiated) { [cleaner] in
            let result = cleaner.clean(targets: targets) { progress in
                Task { @MainActor in
                    self.progressText = "清理 \(progress.completed)/\(progress.total) · 已释放 \(DisplayFormat.byteString(progress.cleanedBytes))"
                    self.progressValue = progress.total == 0 ? 0 : Double(progress.completed) / Double(progress.total)
                }
            }

            await MainActor.run {
                self.lastResult = result
                self.phase = .ready
                self.rescan()
            }
        }
    }
}
