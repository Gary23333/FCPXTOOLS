import SwiftUI

/// 归档清单文件（.archive_manifest.json）内容。
struct ArchiveManifest: Codable {
    let originalName: String
    let originalPath: String
    let archivePath: String
    let totalBytes: Int64
    let archivedAt: Date
    let fileCount: Int
}

/// 素材库归档管理 ViewModel。
/// 扫描、归档、恢复均放后台队列，结果回主线程，UI 不阻塞。
@MainActor
final class ArchiveManagerViewModel: ObservableObject {
    enum Phase: Equatable {
        case empty
        case scanning
        case ready
        case archiving
    }

    @Published var items: [ArchivableItem] = []
    @Published var archiveRecords: [ArchiveRecord] = []
    @Published var phase: Phase = .empty
    @Published var statusText = "选择源目录后开始扫描可归档素材"
    @Published var progressValue: Double = 0
    @Published var errorMessage: String?
    @Published var sourceURL: URL?
    @Published var archiveURL: URL?
    @Published var selectedItemID: ArchivableItem.ID?
    @Published var selectedRecordID: ArchiveRecord.ID?
    @Published private(set) var selectedIDs: Set<ArchivableItem.ID> = []

    private let fm = FileManager.default

    /// 媒体文件扩展名，用于识别媒体文件夹。
    private static let mediaExtensions: Set<String> = [
        "mov", "mp4", "m4v", "avi", "r3d", "braw", "mts", "m2ts",
        "wmv", "flv", "mkv", "m4a", "wav", "aif", "aiff", "caf"
    ]

    // MARK: - 计算属性

    var isBusy: Bool { phase == .scanning || phase == .archiving }
    var canScan: Bool { !isBusy && sourceURL != nil }
    var canArchive: Bool { !isBusy && !selectedIDs.isEmpty && archiveURL != nil }

    var totalBytes: Int64 { items.reduce(0) { $0 + $1.totalBytes } }
    var selectedBytes: Int64 {
        items.filter { selectedIDs.contains($0.id) }.reduce(0) { $0 + $1.totalBytes }
    }
    var archivedCount: Int { archiveRecords.count }
    var archivedBytes: Int64 { archiveRecords.reduce(0) { $0 + $1.totalBytes } }

    var selectedItem: ArchivableItem? {
        guard let id = selectedItemID else { return items.first }
        return items.first { $0.id == id } ?? items.first
    }

    var selectedRecord: ArchiveRecord? {
        guard let id = selectedRecordID else { return archiveRecords.first }
        return archiveRecords.first { $0.id == id } ?? archiveRecords.first
    }

    /// 归档历史持久化路径：~/Library/Application Support/FCPXToolbox/archive_history.json
    private var historyURL: URL {
        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory())
                .appendingPathComponent("Library/Application Support", isDirectory: true)
        let dir = support.appendingPathComponent("FCPXToolbox", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("archive_history.json")
    }

    init() {
        loadHistory()
    }

    // MARK: - 目录选择

    func chooseSourceDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择源目录"
        panel.message = "选择包含 FCPX 资源库（.fcpbundle）或媒体文件夹的目录"
        if panel.runModal() == .OK, let url = panel.url {
            sourceURL = url
            statusText = "已选择源目录：\(url.path)"
        }
    }

    func chooseArchiveDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择归档目录"
        panel.message = "选择用于存放归档素材的目录"
        if panel.runModal() == .OK, let url = panel.url {
            archiveURL = url
            statusText = "已选择归档目录：\(url.path)"
        }
    }

    // MARK: - 扫描

    func scan() {
        guard let sourceURL else { return }
        phase = .scanning
        items = []
        selectedIDs = []
        selectedItemID = nil
        statusText = "扫描中…"
        progressValue = 0.05

        let root = sourceURL
        Task.detached(priority: .userInitiated) {
            let result = Self.scanDirectory(root: root) { progress in
                Task { @MainActor in
                    self.progressValue = min(0.95, progress)
                    self.statusText = "扫描中 \(Int(progress * 100))%"
                }
            }
            await MainActor.run {
                self.items = result
                self.selectedItemID = result.first?.id
                self.phase = .ready
                self.progressValue = 1
                self.statusText = result.isEmpty
                    ? "未发现可归档的素材"
                    : "扫描完成，共 \(result.count) 项，合计 \(DisplayFormat.byteString(self.totalBytes))"
            }
        }
    }

    /// 扫描源目录下的 .fcpbundle 和媒体文件夹。
    private static func scanDirectory(root: URL, progress: @escaping (Double) -> Void) -> [ArchivableItem] {
        let fm = FileManager.default
        var items: [ArchivableItem] = []

        guard let entries = try? fm.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let directories = entries
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        let total = max(directories.count, 1)
        for (index, dir) in directories.enumerated() {
            let ext = dir.pathExtension.lowercased()
            let isLibrary = ext == "fcpbundle"
            let isMedia = isMediaFolder(dir)
            guard isLibrary || isMedia else {
                progress(Double(index + 1) / Double(total))
                continue
            }

            let measured = measure(dir)
            let modified = (try? dir.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
            items.append(ArchivableItem(
                name: dir.lastPathComponent,
                url: dir,
                totalBytes: measured.bytes,
                modifiedAt: modified,
                fileCount: measured.files,
                status: .pending,
                archivePath: nil
            ))
            progress(Double(index + 1) / Double(total))
        }

        return items.sorted { $0.totalBytes > $1.totalBytes }
    }

    /// 判断是否为媒体文件夹（直接包含媒体文件的目录）。
    private static func isMediaFolder(_ url: URL) -> Bool {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return false }
        return entries.contains { file in
            (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
                && mediaExtensions.contains(file.pathExtension.lowercased())
        }
    }

    /// 测量目录大小和文件数。
    private static func measure(_ url: URL) -> (bytes: Int64, files: Int) {
        let fm = FileManager.default
        var bytes: Int64 = 0
        var files = 0
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return (0, 0) }

        for case let file as URL in enumerator {
            if (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
                enumerator.skipDescendants()
                continue
            }
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            bytes += Int64(size)
            files += 1
        }
        return (bytes, files)
    }

    // MARK: - 选择

    func toggleSelection(_ item: ArchivableItem) {
        if selectedIDs.contains(item.id) {
            selectedIDs.remove(item.id)
        } else {
            selectedIDs.insert(item.id)
        }
    }

    func selectAll() {
        selectedIDs = Set(items.map(\.id))
    }

    func selectNone() {
        selectedIDs.removeAll()
    }

    func isSelected(_ item: ArchivableItem) -> Bool {
        selectedIDs.contains(item.id)
    }

    // MARK: - 归档摘要

    /// 返回确认弹窗所需信息；nil 表示无可归档项。
    func archiveSummary() -> (count: Int, bytes: Int64)? {
        let targets = items.filter { selectedIDs.contains($0.id) }
        guard !targets.isEmpty else { return nil }
        return (targets.count, targets.reduce(0) { $0 + $1.totalBytes })
    }

    // MARK: - 归档

    func performArchive() {
        guard let archiveURL else { return }
        let targets = items.filter { selectedIDs.contains($0.id) }
        guard !targets.isEmpty else { return }

        phase = .archiving
        statusText = "归档中…"
        progressValue = 0

        let destination = archiveURL
        let total = targets.count

        Task.detached(priority: .userInitiated) {
            var completed = 0
            var newRecords: [ArchiveRecord] = []
            var failedItems: [String] = []

            for target in targets {
                do {
                    let archiveName = Self.uniqueArchiveName(for: target.name, in: destination)
                    let dest = destination.appendingPathComponent(archiveName)
                    try FileManager.default.copyItem(at: target.url, to: dest)

                    // 写入 .archive_manifest.json 清单文件
                    let manifest = ArchiveManifest(
                        originalName: target.name,
                        originalPath: target.url.path,
                        archivePath: dest.path,
                        totalBytes: target.totalBytes,
                        archivedAt: Date(),
                        fileCount: target.fileCount
                    )
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = .prettyPrinted
                    if let data = try? encoder.encode(manifest) {
                        let manifestURL = dest.appendingPathComponent(".archive_manifest.json")
                        try? data.write(to: manifestURL, options: .atomic)
                    }

                    let record = ArchiveRecord(
                        id: UUID(),
                        originalName: target.name,
                        originalPath: target.url.path,
                        archivePath: dest.path,
                        totalBytes: target.totalBytes,
                        archivedAt: Date(),
                        fileCount: target.fileCount
                    )
                    newRecords.append(record)
                    completed += 1

                    let progress = Double(completed) / Double(total)
                    Task { @MainActor in
                        self.progressValue = progress
                        self.statusText = "归档 \(completed)/\(total) · \(target.name)"
                        if let idx = self.items.firstIndex(where: { $0.id == target.id }) {
                            self.items[idx].status = .archived
                            self.items[idx].archivePath = dest.path
                        }
                    }
                } catch {
                    failedItems.append(target.name)
                    Task { @MainActor in
                        if let idx = self.items.firstIndex(where: { $0.id == target.id }) {
                            self.items[idx].status = .failed
                        }
                    }
                }
            }

            await MainActor.run {
                self.archiveRecords.insert(contentsOf: newRecords, at: 0)
                self.selectedIDs.removeAll()
                self.saveHistory()
                self.phase = .ready
                self.progressValue = 1
                if failedItems.isEmpty {
                    let bytes = newRecords.reduce(0) { $0 + $1.totalBytes }
                    self.statusText = "归档完成，共 \(newRecords.count) 项，合计 \(DisplayFormat.byteString(bytes))"
                } else {
                    self.statusText = "归档完成 \(newRecords.count) 项，失败 \(failedItems.count) 项：\(failedItems.joined(separator: "、"))"
                }
            }
        }
    }

    /// 生成不冲突的归档目录名。
    private static func uniqueArchiveName(for name: String, in directory: URL) -> String {
        var candidate = name
        var counter = 1
        while FileManager.default.fileExists(atPath: directory.appendingPathComponent(candidate).path) {
            counter += 1
            candidate = "\(name) (\(counter))"
        }
        return candidate
    }

    // MARK: - 恢复

    /// 从归档目录恢复素材到原位置（复制，不删除归档）。
    func restore(record: ArchiveRecord) {
        phase = .archiving
        statusText = "恢复中：\(record.originalName)"
        progressValue = 0.1

        let archiveURL = URL(fileURLWithPath: record.archivePath)
        let originalURL = URL(fileURLWithPath: record.originalPath)

        Task.detached(priority: .userInitiated) {
            do {
                let parent = originalURL.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: originalURL.path) {
                    throw NSError(
                        domain: "ArchiveManager",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "原位置已存在同名项目：\(originalURL.path)"]
                    )
                }
                try FileManager.default.copyItem(at: archiveURL, to: originalURL)
                await MainActor.run {
                    self.progressValue = 1
                    self.phase = .ready
                    self.statusText = "已恢复：\(record.originalName) → \(originalURL.path)"
                }
            } catch {
                await MainActor.run {
                    self.phase = .ready
                    self.errorMessage = "恢复失败：\(error.localizedDescription)"
                    self.statusText = "恢复失败"
                }
            }
        }
    }

    // MARK: - 删除归档记录

    /// 删除归档记录并将归档目录移到废纸篓。
    func deleteRecord(_ record: ArchiveRecord) {
        let archiveURL = URL(fileURLWithPath: record.archivePath)
        Task.detached(priority: .userInitiated) {
            do {
                try FileMover.trash(archiveURL)
                await MainActor.run {
                    self.archiveRecords.removeAll { $0.id == record.id }
                    if self.selectedRecordID == record.id {
                        self.selectedRecordID = nil
                    }
                    self.saveHistory()
                    self.statusText = "已删除归档：\(record.originalName)"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "删除归档失败：\(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Finder

    func revealInFinder(_ item: ArchivableItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    func revealRecordInFinder(_ record: ArchiveRecord) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: record.archivePath)])
    }

    // MARK: - 持久化

    private func loadHistory() {
        guard let data = try? Data(contentsOf: historyURL),
              let records = try? JSONDecoder().decode([ArchiveRecord].self, from: data) else {
            return
        }
        archiveRecords = records
    }

    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(archiveRecords)
            try data.write(to: historyURL, options: .atomic)
        } catch {
            errorMessage = "保存归档历史失败：\(error.localizedDescription)"
        }
    }
}

// MARK: - View

struct ArchiveManagerView: View {
    @StateObject private var model = ArchiveManagerViewModel()
    @State private var showArchiveConfirm = false

    var body: some View {
        VStack(spacing: 14) {
            toolbar
            summaryCards
            content
            statusBar
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .confirmationDialog("确认归档所选素材？", isPresented: $showArchiveConfirm, titleVisibility: .visible) {
            Button("复制到归档目录", role: .destructive) {
                model.performArchive()
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let s = model.archiveSummary() {
                Text("将 \(s.count) 个素材复制到归档目录，合计 \(DisplayFormat.byteString(s.bytes))。\n\n归档为复制操作，不会删除源文件。每个归档会生成 .archive_manifest.json 清单文件。")
            }
        }
        .alert("操作失败", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: 12) {
            Image(systemName: "archivebox")
                .font(.system(size: 26))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("素材库归档管理")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(model.sourceURL?.path ?? "选择包含 FCPX 资源库或媒体文件夹的源目录")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            toolbarButton("选择源目录", systemImage: "folder.badge.plus", isEnabled: !model.isBusy) {
                model.chooseSourceDirectory()
            }
            toolbarButton("选择归档目录", systemImage: "archivebox", isEnabled: !model.isBusy) {
                model.chooseArchiveDirectory()
            }
            toolbarButton("扫描", systemImage: "magnifyingglass", isEnabled: model.canScan) {
                model.scan()
            }
            toolbarButton("归档所选", systemImage: "archivebox.fill", isEnabled: model.canArchive, isProminent: true) {
                showArchiveConfirm = true
            }
        }
    }

    private func toolbarButton(
        _ title: String,
        systemImage: String,
        isEnabled: Bool,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isProminent ? Theme.accent : Theme.panel)
                .foregroundStyle(isProminent ? Color.white : Theme.accent)
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(isProminent ? Theme.accent : Theme.line, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .opacity(isEnabled ? 1 : 0.42)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    // MARK: - 统计卡片

    private var summaryCards: some View {
        HStack(spacing: 10) {
            summaryCard("可归档项", "\(model.items.count)", Theme.textPrimary)
            summaryCard("可归档大小", DisplayFormat.byteString(model.totalBytes), Theme.accent)
            summaryCard("已归档", "\(model.archivedCount)", Theme.textPrimary)
            summaryCard("归档总大小", DisplayFormat.byteString(model.archivedBytes), Theme.textPrimary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func summaryCard(_ title: String, _ value: String, _ color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
            .padding(.horizontal, 14)
        }
    }

    // MARK: - 主区：列表 + 详情

    private var content: some View {
        HStack(spacing: 10) {
            itemList
                .frame(maxWidth: .infinity)
                .frame(minWidth: 320)
                .layoutPriority(0.4)
            rightPanel
                .frame(maxWidth: .infinity)
                .layoutPriority(0.6)
        }
        .frame(maxHeight: .infinity)
    }

    private var itemList: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("可归档素材")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if !model.items.isEmpty {
                        Button("全选") { model.selectAll() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                            .disabled(model.isBusy)
                        Button("清除") { model.selectNone() }
                            .buttonStyle(.plain)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.accent)
                            .disabled(model.isBusy)
                    }
                }

                if model.items.isEmpty {
                    emptyHint
                } else {
                    List(selection: Binding(
                        get: { model.selectedItemID },
                        set: { model.selectedItemID = $0 }
                    )) {
                        ForEach(model.items) { item in
                            itemRow(item).tag(item.id)
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
            }
            .padding(12)
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "archivebox")
                .font(.system(size: 34))
                .foregroundStyle(Theme.textSecondary)
            Text("选择源目录并扫描")
                .foregroundStyle(Theme.textSecondary)
            Text("扫描后将列出可归档的 .fcpbundle 和媒体文件夹。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func itemRow(_ item: ArchivableItem) -> some View {
        HStack(spacing: 10) {
            Button {
                model.toggleSelection(item)
            } label: {
                Image(systemName: model.isSelected(item) ? "checkmark.square.fill" : "square")
                    .foregroundStyle(model.isSelected(item) ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(model.isBusy)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(DisplayFormat.dateString(item.modifiedAt)) · \(item.fileCount) 个文件")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(DisplayFormat.byteString(item.totalBytes))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                statusBadge(item.status)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusBadge(_ status: ArchiveStatus) -> some View {
        let color = statusColor(status)
        return Text(status.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func statusColor(_ status: ArchiveStatus) -> Color {
        switch status {
        case .pending: return Theme.textSecondary
        case .archiving, .restoring: return Theme.warning
        case .archived: return Theme.safe
        case .failed: return Theme.danger
        }
    }

    // MARK: - 右侧：详情 + 历史

    private var rightPanel: some View {
        VStack(spacing: 10) {
            detailCard
                .frame(maxHeight: .infinity)
                .layoutPriority(0.5)
            historyCard
                .frame(maxHeight: .infinity)
                .layoutPriority(0.5)
        }
    }

    private var detailCard: some View {
        Card {
            Group {
                if let item = model.selectedItem {
                    detailContent(item)
                } else {
                    VStack(spacing: 6) {
                        Spacer()
                        Text("未选择素材")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("选择左侧列表中的素材查看详情")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(14)
        }
    }

    private func detailContent(_ item: ArchivableItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(item.url.path)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                Spacer()
                statusBadge(item.status)
                Button {
                    model.revealInFinder(item)
                } label: {
                    Label("在 Finder 显示", systemImage: "folder")
                }
                .buttonStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 18) {
                statPair("总大小", DisplayFormat.byteString(item.totalBytes), Theme.textPrimary)
                statPair("文件数", "\(item.fileCount)", Theme.textPrimary)
                statPair("修改时间", DisplayFormat.dateString(item.modifiedAt), Theme.textSecondary)
            }

            if let archivePath = item.archivePath {
                Divider()
                VStack(alignment: .leading, spacing: 3) {
                    Text("归档位置")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                    Text(archivePath)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var historyCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("归档历史")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    if let record = model.selectedRecord {
                        Button {
                            model.restore(record: record)
                        } label: {
                            Label("恢复", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)
                        .disabled(model.isBusy)

                        Button {
                            model.revealRecordInFinder(record)
                        } label: {
                            Label("Finder", systemImage: "folder")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)

                        Button {
                            model.deleteRecord(record)
                        } label: {
                            Label("删除", systemImage: "trash")
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.danger)
                        .disabled(model.isBusy)
                    }
                }

                if model.archiveRecords.isEmpty {
                    VStack(spacing: 6) {
                        Spacer()
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.textSecondary)
                        Text("暂无归档记录")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: Binding(
                        get: { model.selectedRecordID },
                        set: { model.selectedRecordID = $0 }
                    )) {
                        ForEach(model.archiveRecords) { record in
                            recordRow(record).tag(record.id)
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
            }
            .padding(12)
        }
    }

    private func recordRow(_ record: ArchiveRecord) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(record.originalName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(DisplayFormat.dateString(record.archivedAt)) · \(record.fileCount) 个文件")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(DisplayFormat.byteString(record.totalBytes))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                Text(record.archivePath)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(width: 160, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }

    private func statPair(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: 6) {
            ProgressView(value: model.progressValue)
                .tint(Theme.accent)
            HStack {
                Text(model.statusText)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                if model.canArchive {
                    Text("已选 \(model.selectedIDs.count) 项 · \(DisplayFormat.byteString(model.selectedBytes))")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
    }
}
