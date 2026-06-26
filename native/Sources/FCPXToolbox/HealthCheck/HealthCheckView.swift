import SwiftUI

/// 资源库健康检查 ViewModel。
/// 扫描在后台 Task 中执行，结果回主线程刷新 UI。
@MainActor
final class HealthCheckViewModel: ObservableObject {
    enum Phase: Equatable {
        case empty
        case scanning
        case ready
    }

    @Published var phase: Phase = .empty
    @Published var reports: [LibraryHealthReport] = []
    @Published var selectedReportID: LibraryHealthReport.ID?
    @Published var statusText = "选择包含 Final Cut Pro 资源库的目录开始健康检查"
    @Published var progressValue: Double = 0
    @Published var rootURL: URL?

    private var scanTask: Task<Void, Never>?

    // MARK: - 统计

    var totalCount: Int { reports.count }
    var healthyCount: Int { reports.filter { $0.overallStatus == .healthy }.count }
    var warningCount: Int { reports.filter { $0.overallStatus == .warning }.count }
    var criticalCount: Int { reports.filter { $0.overallStatus == .critical }.count }

    var isBusy: Bool { phase == .scanning }
    var canRescan: Bool { !isBusy && rootURL != nil }

    var selectedReport: LibraryHealthReport? {
        guard let id = selectedReportID else { return reports.first }
        return reports.first { $0.id == id } ?? reports.first
    }

    // MARK: - 目录选择

    func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "健康检查"
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
        scanTask?.cancel()
        statusText = "正在停止…"
    }

    // MARK: - 扫描

    private func startScan(_ url: URL) {
        scanTask?.cancel()
        phase = .scanning
        reports = []
        selectedReportID = nil
        progressValue = 0
        statusText = "正在扫描目录…"

        scanTask = Task.detached(priority: .userInitiated) {
            let started = Date()
            let libraries = HealthCheckScan.findLibraries(root: url)

            if libraries.isEmpty {
                await MainActor.run {
                    self.phase = .ready
                    self.progressValue = 1
                    self.statusText = "未在所选目录中找到 Final Cut Pro 资源库（.fcpbundle）。"
                }
                return
            }

            for (index, lib) in libraries.enumerated() {
                if Task.isCancelled { break }
                let name = lib.lastPathComponent
                await MainActor.run {
                    self.statusText = "正在检查 \(name)（\(index + 1)/\(libraries.count)）"
                    self.progressValue = Double(index) / Double(libraries.count)
                }
                let report = HealthCheckScan.buildReport(for: lib)
                await MainActor.run {
                    self.reports.append(report)
                    if self.selectedReportID == nil {
                        self.selectedReportID = report.id
                    }
                }
            }

            let duration = Date().timeIntervalSince(started)
            await MainActor.run {
                self.reports.sort { a, b in
                    let sa = healthSeverity(a.overallStatus)
                    let sb = healthSeverity(b.overallStatus)
                    if sa != sb { return sa > sb }
                    return a.totalBytes > b.totalBytes
                }
                if self.selectedReportID == nil
                    || !self.reports.contains(where: { $0.id == self.selectedReportID }) {
                    self.selectedReportID = self.reports.first?.id
                }
                self.phase = .ready
                self.progressValue = 1
                self.statusText = String(format: "检查完成，共 %d 个资源库，用时 %.1fs", self.reports.count, duration)
            }
        }
    }

    // MARK: - 修复逻辑 (v0.9.0)

    func canRepair(_ item: HealthCheckItem) -> Bool {
        guard item.status != .healthy else { return false }
        return ["渲染缓存", "代理媒体", "优化媒体"].contains(item.title)
    }

    func repair(_ item: HealthCheckItem, in report: LibraryHealthReport) {
        guard !isBusy else { return }
        phase = .scanning
        statusText = "正在修复「\(item.title)」..."

        let bundleURL = report.libraryURL
        let title = item.title

        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var success = false

            var subfolderNames: [String] = []
            if title == "渲染缓存" {
                subfolderNames = ["Render Files"]
            } else if title == "代理媒体" {
                subfolderNames = ["Proxy Media"]
            } else if title == "优化媒体" {
                subfolderNames = ["High Quality Media"]
            }

            if !subfolderNames.isEmpty {
                let enumerator = fm.enumerator(
                    at: bundleURL,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                var targetsToDelete: [URL] = []
                if let enumr = enumerator {
                    for case let url as URL in enumr {
                        if subfolderNames.contains(url.lastPathComponent) {
                            targetsToDelete.append(url)
                            enumr.skipDescendants()
                        }
                    }
                }

                var errors = 0
                for url in targetsToDelete {
                    do {
                        var resultingURL: NSURL?
                        try fm.trashItem(at: url, resultingItemURL: &resultingURL)
                    } catch {
                        errors += 1
                    }
                }
                success = (errors == 0 && !targetsToDelete.isEmpty)
            }

            await MainActor.run {
                self.phase = .ready
                if success {
                    self.statusText = "修复「\(title)」完成！已安全清理对应的冗余缓存。"
                } else {
                    self.statusText = "修复「\(title)」已完成，部分项目可能无法直接删除。"
                }
                self.rescan() // 重新扫描刷新状态
            }
        }
    }
}

// MARK: - 状态严重度排序

/// 严重度数值，越大越严重，用于列表排序。
private func healthSeverity(_ status: HealthStatus) -> Int {
    switch status {
    case .critical: return 3
    case .warning: return 2
    case .healthy: return 1
    case .unknown: return 0
    }
}

// MARK: - 扫描与检查逻辑（非隔离，可在后台 Task 中调用）

/// 健康检查阈值。
private enum Threshold {
    static let totalBytesWarning: Int64 = 50 * 1024 * 1024 * 1024        // 50 GB
    static let totalBytesCritical: Int64 = 200 * 1024 * 1024 * 1024      // 200 GB
    static let renderCacheWarning: Int64 = 10 * 1024 * 1024 * 1024       // 10 GB
    static let renderCacheCritical: Int64 = 50 * 1024 * 1024 * 1024      // 50 GB
    static let originalMediaWarning: Int64 = 100 * 1024 * 1024 * 1024    // 100 GB
    static let originalMediaCritical: Int64 = 500 * 1024 * 1024 * 1024   // 500 GB
    static let proxyMediaWarning: Int64 = 20 * 1024 * 1024 * 1024        // 20 GB
    static let proxyMediaCritical: Int64 = 100 * 1024 * 1024 * 1024      // 100 GB
    static let optimizedMediaWarning: Int64 = 50 * 1024 * 1024 * 1024    // 50 GB
    static let optimizedMediaCritical: Int64 = 200 * 1024 * 1024 * 1024  // 200 GB
    static let diskFreeWarning: Int64 = 50 * 1024 * 1024 * 1024          // 50 GB
    static let diskFreeCritical: Int64 = 10 * 1024 * 1024 * 1024         // 10 GB
    static let staleWarningDays: Double = 180                            // 180 天
    static let staleCriticalDays: Double = 365                           // 365 天
}

private enum HealthCheckScan {
    /// 递归查找选定目录下的 .fcpbundle 资源库。
    static func findLibraries(root: URL) -> [URL] {
        let fm = FileManager.default
        var libraries: [URL] = []

        // 若根目录本身就是一个资源库，直接纳入。
        if root.pathExtension.lowercased() == "fcpbundle" {
            libraries.append(root)
        }

        guard let enumerator = fm.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return libraries }

        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                enumerator.skipDescendants()
                continue
            }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            if url.pathExtension.lowercased() == "fcpbundle" {
                libraries.append(url)
                enumerator.skipDescendants()
            }
        }
        return libraries
    }

    /// 对单个资源库执行全部健康检查并生成报告。
    static func buildReport(for bundle: URL) -> LibraryHealthReport {
        let totalBytes = measure(bundle)
        let media = measureMedia(in: bundle)
        let missingCount = countMissingMedia(in: bundle)
        let freeBytes = diskFreeBytes(at: bundle)
        let modifiedAt = (try? bundle.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate

        let items: [HealthCheckItem] = [
            checkTotalSize(totalBytes),
            checkRenderCache(media.renderFiles),
            checkOriginalMedia(media.originalMedia),
            checkProxyMedia(media.proxyMedia),
            checkOptimizedMedia(media.optimizedMedia),
            checkMissingFiles(missingCount),
            checkDiskSpace(freeBytes),
            checkModifiedTime(modifiedAt)
        ]

        return LibraryHealthReport(
            libraryName: bundle.lastPathComponent,
            libraryURL: bundle,
            totalBytes: totalBytes,
            renderCacheBytes: media.renderFiles,
            originalMediaBytes: media.originalMedia,
            proxyMediaBytes: media.proxyMedia,
            optimizedMediaBytes: media.optimizedMedia,
            modifiedAt: modifiedAt,
            checkItems: items
        )
    }

    /// 测量目录总字节数（跳过符号链接，避免重复计算）。
    static func measure(_ url: URL) -> Int64 {
        let fm = FileManager.default
        var bytes: Int64 = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let file as URL in enumerator {
            if (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                enumerator.skipDescendants()
                continue
            }
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            bytes += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return bytes
    }

    /// 按目录名汇总各类媒体占用：渲染缓存、原始媒体、代理媒体、优化媒体。
    static func measureMedia(in bundle: URL) -> (renderFiles: Int64, originalMedia: Int64, proxyMedia: Int64, optimizedMedia: Int64) {
        let fm = FileManager.default
        var renderFiles: Int64 = 0
        var originalMedia: Int64 = 0
        var proxyMedia: Int64 = 0
        var optimizedMedia: Int64 = 0

        guard let enumerator = fm.enumerator(
            at: bundle,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, 0, 0, 0) }

        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                enumerator.skipDescendants()
                continue
            }
            guard (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
            switch url.lastPathComponent {
            case "Render Files":
                renderFiles += measure(url)
                enumerator.skipDescendants()
            case "Original Media":
                originalMedia += measure(url)
                enumerator.skipDescendants()
            case "Proxy Media":
                proxyMedia += measure(url)
                enumerator.skipDescendants()
            case "High Quality Media":
                optimizedMedia += measure(url)
                enumerator.skipDescendants()
            default:
                break
            }
        }
        return (renderFiles, originalMedia, proxyMedia, optimizedMedia)
    }

    /// 在 .fcpevent 文件中查找缺失媒体标记（missing="1" / missing="true"）。
    static func countMissingMedia(in bundle: URL) -> Int {
        let fm = FileManager.default
        var count = 0
        guard let enumerator = fm.enumerator(
            at: bundle,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        for case let url as URL in enumerator {
            if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                enumerator.skipDescendants()
                continue
            }
            guard url.pathExtension.lowercased() == "fcpevent" else { continue }
            guard (try? url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else { continue }
            guard let text = String(data: data, encoding: .utf8) else { continue }
            count += countOccurrences(of: "missing=\"1\"", in: text)
            count += countOccurrences(of: "missing=\"true\"", in: text)
        }
        return count
    }

    /// 获取资源库所在卷的可用空间。
    static func diskFreeBytes(at url: URL) -> Int64 {
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]),
           let cap = values.volumeAvailableCapacityForImportantUsage {
            return cap
        }
        if let values = try? url.resourceValues(forKeys: [.volumeAvailableCapacityKey]),
           let cap = values.volumeAvailableCapacity {
            return Int64(cap)
        }
        return 0
    }

    // MARK: - 单项检查

    static func checkTotalSize(_ bytes: Int64) -> HealthCheckItem {
        let status: HealthStatus
        let recommendation: String?
        if bytes >= Threshold.totalBytesCritical {
            status = .critical
            recommendation = "资源库体积过大，建议归档或迁移旧项目，并清理不再使用的素材。"
        } else if bytes >= Threshold.totalBytesWarning {
            status = .warning
            recommendation = "资源库体积偏大，建议定期清理渲染缓存与代理媒体。"
        } else {
            status = .healthy
            recommendation = nil
        }
        return HealthCheckItem(
            title: "资源库总大小",
            status: status,
            detail: "当前占用 \(DisplayFormat.byteString(bytes))。",
            recommendation: recommendation
        )
    }

    static func checkRenderCache(_ bytes: Int64) -> HealthCheckItem {
        let status: HealthStatus
        let recommendation: String?
        if bytes >= Threshold.renderCacheCritical {
            status = .critical
            recommendation = "渲染缓存过大，可安全清理，部分片段需重新渲染。"
        } else if bytes >= Threshold.renderCacheWarning {
            status = .warning
            recommendation = "渲染缓存偏大，建议清理以释放空间。"
        } else {
            status = .healthy
            recommendation = nil
        }
        return HealthCheckItem(
            title: "渲染缓存",
            status: status,
            detail: "Render Files 占用 \(DisplayFormat.byteString(bytes))。",
            recommendation: recommendation
        )
    }

    static func checkOriginalMedia(_ bytes: Int64) -> HealthCheckItem {
        let status: HealthStatus
        let recommendation: String?
        if bytes >= Threshold.originalMediaCritical {
            status = .critical
            recommendation = "原始素材占用过大，建议将不常用素材迁移到外置存储。"
        } else if bytes >= Threshold.originalMediaWarning {
            status = .warning
            recommendation = "原始素材占用偏大，建议整理并归档旧素材。"
        } else {
            status = .healthy
            recommendation = nil
        }
        return HealthCheckItem(
            title: "原始媒体",
            status: status,
            detail: "Original Media 占用 \(DisplayFormat.byteString(bytes))。",
            recommendation: recommendation
        )
    }

    static func checkProxyMedia(_ bytes: Int64) -> HealthCheckItem {
        let status: HealthStatus
        let recommendation: String?
        if bytes >= Threshold.proxyMediaCritical {
            status = .critical
            recommendation = "代理媒体占用过大，若不再使用代理工作流可清理后重新生成。"
        } else if bytes >= Threshold.proxyMediaWarning {
            status = .warning
            recommendation = "代理媒体偏多，建议确认是否仍需要代理剪辑。"
        } else {
            status = .healthy
            recommendation = nil
        }
        return HealthCheckItem(
            title: "代理媒体",
            status: status,
            detail: "Proxy Media 占用 \(DisplayFormat.byteString(bytes))。",
            recommendation: recommendation
        )
    }

    static func checkOptimizedMedia(_ bytes: Int64) -> HealthCheckItem {
        let status: HealthStatus
        let recommendation: String?
        if bytes >= Threshold.optimizedMediaCritical {
            status = .critical
            recommendation = "优化媒体占用过大，若不再需要可清理后重新生成。"
        } else if bytes >= Threshold.optimizedMediaWarning {
            status = .warning
            recommendation = "优化媒体偏多，建议确认是否仍需要优化媒体工作流。"
        } else {
            status = .healthy
            recommendation = nil
        }
        return HealthCheckItem(
            title: "优化媒体",
            status: status,
            detail: "High Quality Media 占用 \(DisplayFormat.byteString(bytes))。",
            recommendation: recommendation
        )
    }

    static func checkMissingFiles(_ count: Int) -> HealthCheckItem {
        let status: HealthStatus = count > 0 ? .critical : .healthy
        let recommendation: String? = count > 0
            ? "检测到缺失媒体，建议在 FCPX 中重新链接素材，或检查外置存储是否已连接。"
            : nil
        return HealthCheckItem(
            title: "缺失媒体",
            status: status,
            detail: count > 0 ? "在事件文件中检测到 \(count) 处缺失标记。" : "未检测到缺失媒体标记。",
            recommendation: recommendation
        )
    }

    static func checkDiskSpace(_ freeBytes: Int64) -> HealthCheckItem {
        let status: HealthStatus
        let recommendation: String?
        if freeBytes <= Threshold.diskFreeCritical {
            status = .critical
            recommendation = "磁盘可用空间严重不足，可能影响渲染与导出，请立即清理或扩容。"
        } else if freeBytes <= Threshold.diskFreeWarning {
            status = .warning
            recommendation = "磁盘可用空间偏少，建议清理不需要的文件。"
        } else {
            status = .healthy
            recommendation = nil
        }
        return HealthCheckItem(
            title: "磁盘可用空间",
            status: status,
            detail: "所在卷可用空间 \(DisplayFormat.byteString(freeBytes))。",
            recommendation: recommendation
        )
    }

    static func checkModifiedTime(_ modified: Date?) -> HealthCheckItem {
        guard let modified else {
            return HealthCheckItem(
                title: "最近修改时间",
                status: .unknown,
                detail: "无法读取资源库修改时间。",
                recommendation: nil
            )
        }
        let days = Date().timeIntervalSince(modified) / (24 * 3600)
        let status: HealthStatus
        let recommendation: String?
        if days >= Threshold.staleCriticalDays {
            status = .critical
            recommendation = "超过一年未修改，可能是废弃项目，建议归档或删除。"
        } else if days >= Threshold.staleWarningDays {
            status = .warning
            recommendation = "较长时间未修改，请确认是否仍需要该项目。"
        } else {
            status = .healthy
            recommendation = nil
        }
        return HealthCheckItem(
            title: "最近修改时间",
            status: status,
            detail: "最后修改于 \(DisplayFormat.dateString(modified))（约 \(Int(days)) 天前）。",
            recommendation: recommendation
        )
    }

    /// 统计子串在文本中出现的次数。
    private static func countOccurrences(of needle: String, in haystack: String) -> Int {
        var count = 0
        var searchStart = haystack.startIndex
        while searchStart < haystack.endIndex,
              let range = haystack.range(of: needle, range: searchStart..<haystack.endIndex) {
            count += 1
            searchStart = range.upperBound
        }
        return count
    }
}

// MARK: - View

struct HealthCheckView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var model: HealthCheckViewModel

    var body: some View {
        VStack(spacing: Spacing.xs) {
            toolbar
            summaryCards
            content
            statusBar
        }
        .padding(Spacing.sm)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            if let globalDir = appState.globalProjectDir, model.rootURL != globalDir {
                model.rootURL = globalDir
                model.rescan()
            }
        }
        .onChange(of: appState.globalProjectDir) { newDir in
            if let newDir = newDir, model.rootURL != newDir {
                model.rootURL = newDir
                model.rescan()
            }
        }
        .onChange(of: model.rootURL) { newRoot in
            if newRoot != appState.globalProjectDir {
                appState.globalProjectDir = newRoot
            }
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        VStack(spacing: Spacing.xs) {
            NeoSectionHeader(
                systemImage: "heart.text.clipboard",
                title: "资源库健康检查",
                subtitle: model.rootURL?.path ?? "选择包含 Final Cut Pro 资源库的目录开始健康检查"
            )
            HStack(spacing: Spacing.xs) {
                Spacer()
                NeoButton(title: "选择目录", systemImage: "folder.badge.plus", style: .secondary, size: .sm, isEnabled: !model.isBusy) {
                    model.chooseDirectory()
                }
                NeoButton(title: "重新扫描", systemImage: "arrow.clockwise", style: .secondary, size: .sm, isEnabled: model.canRescan) {
                    model.rescan()
                }
                NeoButton(title: "停止", systemImage: "stop.circle", style: .destructive, size: .sm, isEnabled: model.isBusy) {
                    model.stopScan()
                }
            }
        }
    }

    // MARK: - 统计卡片

    private var summaryCards: some View {
        HStack(spacing: Spacing.xs) {
            summaryCard("已检查资源库", "\(model.totalCount)", Theme.textPrimary)
            summaryCard("健康", "\(model.healthyCount)", Theme.safe)
            summaryCard("警告", "\(model.warningCount)", Theme.warning)
            summaryCard("严重", "\(model.criticalCount)", Theme.danger)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func summaryCard(_ title: String, _ value: String, _ color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(title)
                    .font(FT.label(12))
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(FT.metric(24))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.xxs)
        }
    }

    // MARK: - 主区：列表 + 详情

    private var content: some View {
        HStack(spacing: Spacing.xs) {
            libraryList
                .frame(maxWidth: .infinity)
                .frame(minWidth: 300)
                .layoutPriority(0.35)
            detailPanel
                .frame(maxWidth: .infinity)
                .layoutPriority(0.65)
        }
        .frame(maxHeight: .infinity)
    }

    private var libraryList: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("资源库列表")
                    .font(FT.data(15, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if model.reports.isEmpty {
                    emptyHint
                } else {
                    List(selection: Binding(
                        get: { model.selectedReportID },
                        set: { model.selectedReportID = $0 }
                    )) {
                        ForEach(model.reports) { report in
                            libraryRow(report).tag(report.id)
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
            }
            .padding(Spacing.xs)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: Spacing.xxs) {
            Spacer()
            Image(systemName: "stethoscope")
                .font(FT.metric())
                .foregroundStyle(Theme.textSecondary)
            Text("选择 Final Cut Pro 资源库所在目录")
                .foregroundStyle(Theme.textSecondary)
            Text("扫描后可查看每个资源库的健康状态。")
                .font(FT.data(12))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func libraryRow(_ report: LibraryHealthReport) -> some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: statusIcon(report.overallStatus))
                .font(FT.data(14))
                .foregroundStyle(statusColor(report.overallStatus))
            VStack(alignment: .leading, spacing: 2) {
                Text(report.libraryName)
                    .font(FT.data(13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(DisplayFormat.dateString(report.modifiedAt))
                    .font(FT.data(11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            Text(DisplayFormat.byteString(report.totalBytes))
                .font(FT.data(12))
                .foregroundStyle(Theme.textPrimary)
        }
        .padding(.vertical, Spacing.xxxs)
    }

    private var detailPanel: some View {
        Card {
            Group {
                if let report = model.selectedReport {
                    detailContent(report)
                } else {
                    VStack(spacing: Spacing.xxxs) {
                        Spacer()
                        Text("未选择资源库")
                            .font(FT.title(18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("扫描后选择一个资源库查看健康检查详情")
                            .font(FT.data(12))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(Spacing.xs)
        }
    }

    private func detailContent(_ report: LibraryHealthReport) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Spacing.xxs) {
                        Text(report.libraryName)
                            .font(FT.title(18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        statusBadge(report.overallStatus)
                    }
                    Text(report.libraryURL.path)
                        .font(FT.data(12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                Button("在 Finder 显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([report.libraryURL])
                }
            }

            HStack(spacing: Spacing.md) {
                statPair("总占用", DisplayFormat.byteString(report.totalBytes), Theme.textPrimary)
                statPair("渲染缓存", DisplayFormat.byteString(report.renderCacheBytes), Theme.textPrimary)
                statPair("原始媒体", DisplayFormat.byteString(report.originalMediaBytes), Theme.textSecondary)
                statPair("代理媒体", DisplayFormat.byteString(report.proxyMediaBytes), Theme.textSecondary)
                statPair("优化媒体", DisplayFormat.byteString(report.optimizedMediaBytes), Theme.textSecondary)
            }

            Divider()
            Text("检查项")
                .font(FT.data(14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ScrollView {
                VStack(spacing: Spacing.xxxs) {
                    ForEach(report.checkItems) { item in
                        checkItemRow(item, in: report)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func checkItemRow(_ item: HealthCheckItem, in report: LibraryHealthReport) -> some View {
        HStack(alignment: .center, spacing: Spacing.xs) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Spacing.xxxs) {
                    Text(item.title)
                        .font(FT.data(13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    NeoBadge(text: item.status.rawValue, style: badgeStyle(for: item.status))
                }
                Text(item.detail)
                    .font(FT.data(11))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let rec = item.recommendation {
                    Text("建议：\(rec)")
                        .font(FT.data(11))
                        .foregroundStyle(statusColor(item.status))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            if model.canRepair(item) {
                NeoButton(title: "一键修复", systemImage: "wrench.and.screwdriver", style: .ghost, size: .sm, isEnabled: !model.isBusy) {
                    model.repair(item, in: report)
                }
            }
        }
        .padding(Spacing.xs)
        .background(Theme.background)
    }

    private func statPair(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(FT.label(11))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(FT.data(16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    private func statusBadge(_ status: HealthStatus) -> some View {
        NeoBadge(text: status.rawValue, style: badgeStyle(for: status))
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: Spacing.xxxs) {
            NeoProgress(value: model.progressValue)
            HStack {
                Text(model.statusText)
                    .font(FT.data(12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
        }
    }

    // MARK: - 颜色与图标

    private func statusColor(_ status: HealthStatus) -> Color {
        switch status {
        case .healthy: return Theme.safe
        case .warning: return Theme.warning
        case .critical: return Theme.danger
        case .unknown: return Theme.textSecondary
        }
    }

    private func statusIcon(_ status: HealthStatus) -> String {
        switch status {
        case .healthy: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    // MARK: - Badge 样式映射

    private func badgeStyle(for status: HealthStatus) -> NeoBadge.Style {
        switch status {
        case .healthy: return .safe
        case .warning: return .warning
        case .critical: return .danger
        case .unknown: return .neutral
        }
    }
}
