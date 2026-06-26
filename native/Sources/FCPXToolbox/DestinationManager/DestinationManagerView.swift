import SwiftUI

/// 输出方式管理 ViewModel：扫描、删除、复制、导出、从预设创建 FCPX 输出目标。
@MainActor
final class DestinationManagerViewModel: ObservableObject {
    @Published var destinations: [DestinationItem] = []
    @Published var selectedDestinationID: DestinationItem.ID?
    @Published var statusText = "准备扫描输出目标目录…"
    @Published var errorMessage: String?
    @Published var scanning = false

    /// 输出目标目录：~/Library/Preferences/Final Cut Pro Destinations/
    var destinationsURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Preferences/Final Cut Pro Destinations")
    }

    /// 预设输出目标模板
    static let presets: [DestinationPreset] = [
        DestinationPreset(name: "导出文件（H.264, 1080p）",
                          type: .exportFile,
                          description: "H.264 编码，1920×1080，适合网络分享",
                          defaultFormat: "H.264",
                          defaultResolution: "1920x1080"),
        DestinationPreset(name: "导出文件（ProRes 422, 1080p）",
                          type: .exportFile,
                          description: "Apple ProRes 422，1920×1080，后期友好",
                          defaultFormat: "ProRes 422",
                          defaultResolution: "1920x1080"),
        DestinationPreset(name: "导出文件（H.265, 4K）",
                          type: .exportFile,
                          description: "H.265/HEVC，3840×2160，高压缩高画质",
                          defaultFormat: "H.265",
                          defaultResolution: "3840x2160"),
        DestinationPreset(name: "Apple 设备（iPad/iPhone）",
                          type: .appleDevices,
                          description: "适配 iPad / iPhone 播放",
                          defaultFormat: "H.264",
                          defaultResolution: "1920x1080"),
        DestinationPreset(name: "仅音频（AAC）",
                          type: .audioOnly,
                          description: "仅导出 AAC 音频轨道",
                          defaultFormat: "AAC",
                          defaultResolution: "默认"),
        DestinationPreset(name: "母版文件（ProRes 422 HQ）",
                          type: .masterFile,
                          description: "Apple ProRes 422 HQ 母版",
                          defaultFormat: "ProRes 422 HQ",
                          defaultResolution: "1920x1080"),
    ]

    var presets: [DestinationPreset] { Self.presets }

    var selectedDestination: DestinationItem? {
        guard let id = selectedDestinationID else { return nil }
        return destinations.first { $0.id == id }
    }

    var totalCount: Int { destinations.count }
    var customCount: Int { destinations.filter { $0.isCustom }.count }
    var defaultCount: Int { destinations.filter { $0.isDefault }.count }

    // MARK: - 扫描

    /// 扫描 ~/Library/Preferences/Final Cut Pro Destinations/ 目录下的所有输出目标文件。
    func scan() {
        scanning = true
        destinations = []
        selectedDestinationID = nil
        errorMessage = nil
        statusText = "扫描中…"

        let folderURL = destinationsURL
        Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            var items: [DestinationItem] = []
            if let entries = try? fm.contentsOfDirectory(
                at: folderURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) {
                for url in entries where !url.hasDirectoryPath {
                    if let item = DestinationItem.from(url: url) {
                        items.append(item)
                    }
                }
                items.sort { ($0.modifiedAt ?? .distantPast) > ($1.modifiedAt ?? .distantPast) }
            }
            await MainActor.run {
                self.destinations = items
                self.selectedDestinationID = items.first?.id
                self.scanning = false
                self.statusText = items.isEmpty
                    ? "未发现输出目标"
                    : "共发现 \(items.count) 个输出目标"
            }
        }
    }

    // MARK: - 删除（移到废纸篓）

    /// 删除输出目标，统一走废纸篓，可从废纸篓恢复。
    func deleteDestination(_ item: DestinationItem) {
        statusText = "正在移到废纸篓：\(item.name)"
        let fileURL = item.fileURL
        Task.detached(priority: .userInitiated) {
            do {
                try FileMover.trash(fileURL)
                await MainActor.run {
                    self.destinations.removeAll { $0.id == item.id }
                    if self.selectedDestinationID == item.id {
                        self.selectedDestinationID = self.destinations.first?.id
                    }
                    self.statusText = "已移到废纸篓：\(item.name)"
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "删除失败：\(error.localizedDescription)"
                    self.statusText = "删除失败"
                }
            }
        }
    }

    // MARK: - 在 Finder 中显示

    func openInFinder(_ item: DestinationItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }

    func openDestinationsFolder() {
        let url = destinationsURL
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            errorMessage = "输出目标目录不存在：\(url.path)"
        }
    }

    // MARK: - 复制输出目标

    func duplicateDestination(_ item: DestinationItem) {
        let folderURL = item.fileURL.deletingLastPathComponent()
        let baseName = item.fileURL.deletingPathExtension().lastPathComponent
        let ext = item.fileURL.pathExtension
        var counter = 2
        var copyName = "\(baseName) 副本"
        var copyURL = makeURL(folder: folderURL, name: copyName, ext: ext)
        while FileManager.default.fileExists(atPath: copyURL.path) {
            copyName = "\(baseName) 副本 \(counter)"
            copyURL = makeURL(folder: folderURL, name: copyName, ext: ext)
            counter += 1
        }
        do {
            try FileManager.default.copyItem(at: item.fileURL, to: copyURL)
            statusText = "已复制：\(copyName)"
            scan()
        } catch {
            errorMessage = "复制失败：\(error.localizedDescription)"
            statusText = "复制失败"
        }
    }

    private func makeURL(folder: URL, name: String, ext: String) -> URL {
        ext.isEmpty
            ? folder.appendingPathComponent(name)
            : folder.appendingPathComponent(name).appendingPathExtension(ext)
    }

    // MARK: - 从预设创建

    /// 从预设模板创建新的输出目标 .fcpxdest 文件。
    func createFromPreset(_ preset: DestinationPreset) {
        let folderURL = destinationsURL
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        } catch {
            errorMessage = "无法创建目录：\(error.localizedDescription)"
            return
        }
        var name = preset.name
        var fileURL = folderURL.appendingPathComponent("\(name).fcpxdest")
        var counter = 2
        while FileManager.default.fileExists(atPath: fileURL.path) {
            name = "\(preset.name) \(counter)"
            fileURL = folderURL.appendingPathComponent("\(name).fcpxdest")
            counter += 1
        }
        let plist: [String: Any] = [
            "Name": name,
            "Type": typeIdentifier(for: preset.type),
            "Format": preset.defaultFormat,
            "Resolution": preset.defaultResolution,
            "IsDefault": false,
        ]
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: fileURL, options: .atomic)
            statusText = "已创建输出目标：\(name)"
            scan()
        } catch {
            errorMessage = "创建失败：\(error.localizedDescription)"
            statusText = "创建失败"
        }
    }

    private func typeIdentifier(for type: DestinationType) -> String {
        switch type {
        case .exportFile: return "Exporter"
        case .youTube: return "YouTube"
        case .vimeo: return "Vimeo"
        case .appleDevices: return "AppleDevices"
        case .dvd: return "DVD"
        case .bluRay: return "BluRay"
        case .masterFile: return "MasterFile"
        case .audioOnly: return "AudioOnly"
        case .custom: return "Custom"
        case .unknown: return "Unknown"
        }
    }

    // MARK: - 导出配置文件

    /// 通过 NSSavePanel 将输出目标配置导出到指定位置。
    func exportDestination(_ item: DestinationItem) {
        let panel = NSSavePanel()
        panel.title = "导出输出目标配置"
        panel.nameFieldStringValue = item.fileURL.lastPathComponent
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try FileManager.default.copyItem(at: item.fileURL, to: url)
            statusText = "已导出到：\(url.path)"
        } catch {
            errorMessage = "导出失败：\(error.localizedDescription)"
            statusText = "导出失败"
        }
    }
}

/// 输出方式管理视图：列表 + 详情 + 新建预设。
struct DestinationManagerView: View {
    @StateObject private var model = DestinationManagerViewModel()
    @State private var itemPendingDelete: DestinationItem?

    private let presetColumns = [GridItem(.adaptive(minimum: 220, maximum: 280), spacing: Spacing.sm)]

    var body: some View {
        VStack(spacing: Spacing.xs) {
            toolbar
            summaryCards
            content
            newDestinationSection
            statusBar
        }
        .padding(Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .onAppear {
            if model.destinations.isEmpty && !model.scanning {
                model.scan()
            }
        }
        .confirmationDialog("删除这个输出目标？",
                            isPresented: deleteConfirmationBinding,
                            titleVisibility: .visible) {
            Button("移到废纸篓", role: .destructive) {
                if let item = itemPendingDelete {
                    model.deleteDestination(item)
                }
                itemPendingDelete = nil
            }
            Button("取消", role: .cancel) {
                itemPendingDelete = nil
            }
        } message: {
            if let item = itemPendingDelete {
                Text("将「\(item.name)」移到废纸篓。此操作不会永久删除，可从废纸篓恢复。")
            }
        }
        .alert("输出目标操作失败", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        HStack(spacing: Spacing.xs) {
            NeoSectionHeader(
                systemImage: "square.and.arrow.up.on.square",
                title: "输出方式管理",
                subtitle: model.destinationsURL.path
            )
            NeoButton(
                title: "重新扫描",
                systemImage: "arrow.clockwise",
                style: .secondary,
                size: .sm,
                isEnabled: !model.scanning
            ) {
                model.scan()
            }
            NeoButton(
                title: "打开目录",
                systemImage: "folder",
                style: .secondary,
                size: .sm,
                isEnabled: true
            ) {
                model.openDestinationsFolder()
            }
        }
    }

    // MARK: - 统计卡片

    private var summaryCards: some View {
        HStack(spacing: Spacing.sm) {
            summaryCard("输出目标总数", "\(model.totalCount)", Theme.textPrimary, "square.and.arrow")
            summaryCard("自定义数量", "\(model.customCount)", Theme.accent, "wrench.and.screwdriver")
            summaryCard("默认数量", "\(model.defaultCount)", Theme.textPrimary, "checkmark.seal")
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func summaryCard(_ title: String, _ value: String, _ color: Color, _ systemImage: String) -> some View {
        Card {
            HStack(spacing: Spacing.xs) {
                Image(systemName: systemImage)
                    .font(FT.title())
                    .foregroundStyle(color.opacity(0.8))
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(title)
                        .font(FT.label())
                        .foregroundStyle(Theme.textSecondary)
                    Text(value)
                        .font(FT.metric())
                        .foregroundStyle(color)
                }
                Spacer()
            }
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.sm)
        }
    }

    // MARK: - 主内容：列表 + 详情

    private var content: some View {
        HStack(spacing: Spacing.sm) {
            destinationList
                .frame(maxWidth: .infinity)
                .frame(minWidth: 300)
                .layoutPriority(0.4)
            detailPanel
                .frame(maxWidth: .infinity)
                .layoutPriority(0.6)
        }
        .frame(maxHeight: .infinity)
    }

    private var destinationList: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                HStack {
                    Text("输出目标列表")
                        .font(FT.data(15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(model.destinations.count) 项")
                        .font(FT.label(11))
                        .foregroundStyle(Theme.textSecondary)
                }
                if model.scanning && model.destinations.isEmpty {
                    loadingState
                } else if model.destinations.isEmpty {
                    emptyState
                } else {
                    List(selection: Binding(
                        get: { model.selectedDestinationID },
                        set: { model.selectedDestinationID = $0 }
                    )) {
                        ForEach(model.destinations) { item in
                            destinationRow(item).tag(item.id)
                        }
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                }
            }
            .padding(Spacing.xs)
        }
    }

    private func destinationRow(_ item: DestinationItem) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: item.type.systemImage)
                .font(FT.data(18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                HStack(spacing: Spacing.xxxs) {
                    Text(item.name)
                        .font(FT.data(13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if item.isDefault {
                        NeoBadge(text: "默认", style: .accent)
                    }
                }
                Text("\(item.format) · \(item.resolution)")
                    .font(FT.data(11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
            Text(DisplayFormat.dateString(item.modifiedAt))
                .font(FT.data(11))
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(.vertical, Spacing.xxxs)
        .contentShape(Rectangle())
        .contextMenu {
            Button("在 Finder 显示") { model.openInFinder(item) }
            Button("复制") { model.duplicateDestination(item) }
            Button("导出…") { model.exportDestination(item) }
            Divider()
            Button("删除", role: .destructive) { itemPendingDelete = item }
        }
    }

    private var loadingState: some View {
        VStack(spacing: Spacing.sm) {
            Spacer()
            ProgressView().controlSize(.large)
            Text(model.statusText)
                .font(FT.label())
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xxs) {
            Spacer()
            Image(systemName: "square.and.arrow.up.on.square")
                .font(FT.metric())
                .foregroundStyle(Theme.textSecondary)
            Text("未发现输出目标")
                .foregroundStyle(Theme.textSecondary)
            Text(model.statusText)
                .font(FT.label())
                .foregroundStyle(Theme.textSecondary)
            Button("打开目录") { model.openDestinationsFolder() }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .font(FT.label(12, weight: .semibold))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 详情面板

    private var detailPanel: some View {
        Card {
            Group {
                if let item = model.selectedDestination {
                    detailContent(item)
                } else {
                    VStack(spacing: Spacing.xxxs) {
                        Spacer()
                        Text("未选择输出目标")
                            .font(FT.data(18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("在左侧列表选择一项查看详情")
                            .font(FT.label())
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(Spacing.sm)
        }
    }

    private func detailContent(_ item: DestinationItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: item.type.systemImage)
                    .font(FT.metric())
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    HStack(spacing: Spacing.xxxs) {
                        Text(item.name)
                            .font(FT.data(18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        if item.isDefault {
                            NeoBadge(text: "默认", style: .accent)
                        }
                    }
                    Text(item.type.rawValue)
                        .font(FT.label())
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }

            Divider()

            VStack(spacing: Spacing.xxs) {
                infoRow(title: "类型", value: item.type.rawValue)
                infoRow(title: "格式", value: item.format)
                infoRow(title: "分辨率", value: item.resolution)
                infoRow(title: "文件路径", value: item.fileURL.path, isPath: true)
                infoRow(title: "修改时间", value: DisplayFormat.dateString(item.modifiedAt))
                infoRow(title: "自定义", value: item.isCustom ? "是" : "否")
            }

            Divider()

            HStack(spacing: Spacing.xxs) {
                NeoButton(
                    title: "在 Finder 显示",
                    systemImage: "folder",
                    style: .secondary,
                    size: .sm
                ) {
                    model.openInFinder(item)
                }
                NeoButton(
                    title: "复制",
                    systemImage: "plus.square.on.square",
                    style: .secondary,
                    size: .sm
                ) {
                    model.duplicateDestination(item)
                }
                NeoButton(
                    title: "导出…",
                    systemImage: "square.and.arrow.up",
                    style: .secondary,
                    size: .sm
                ) {
                    model.exportDestination(item)
                }
                Spacer()
                NeoButton(
                    title: "删除",
                    systemImage: "trash",
                    style: .destructive,
                    size: .sm
                ) {
                    itemPendingDelete = item
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func infoRow(title: String, value: String, isPath: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text(title)
                .font(FT.label())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 64, alignment: .leading)
            Text(value)
                .font(FT.label())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(isPath ? 2 : 1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - 新建输出目标

    private var newDestinationSection: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "plus.square.dashed")
                        .foregroundStyle(Theme.accent)
                    Text("新建输出目标")
                        .font(FT.data(15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("从预设模板创建")
                        .font(FT.label(11))
                        .foregroundStyle(Theme.textSecondary)
                }
                LazyVGrid(columns: presetColumns, spacing: Spacing.sm) {
                    ForEach(model.presets) { preset in
                        presetCard(preset)
                    }
                }
            }
            .padding(Spacing.xs)
        }
    }

    private func presetCard(_ preset: DestinationPreset) -> some View {
        Button {
            model.createFromPreset(preset)
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: preset.type.systemImage)
                    .font(FT.data(18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(preset.name)
                        .font(FT.data(12, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(preset.description)
                        .font(FT.label(10))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "plus.circle")
                    .font(FT.data())
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .background(Theme.background)
            .overlay(
                Rectangle()
                    .stroke(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        HStack(spacing: Spacing.xxs) {
            if model.scanning {
                ProgressView()
                    .controlSize(.small)
            }
            Text(model.statusText)
                .font(FT.label())
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
    }

    // MARK: - 绑定

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { itemPendingDelete != nil },
            set: { if !$0 { itemPendingDelete = nil } }
        )
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )
    }
}
