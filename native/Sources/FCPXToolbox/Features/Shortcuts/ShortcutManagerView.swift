import SwiftUI

/// 快捷键配置预设管理器视图。
struct ShortcutManagerView: View {
    @State private var items: [ShortcutItem] = []
    @State private var searchText = ""
    @State private var selectedItemID: URL?
    @State private var scanning = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    @State private var pendingDeleteItem: ShortcutItem?

    private let scanner = ShortcutScanner()

    var filteredItems: [ShortcutItem] {
        items.filter { item in
            searchText.isEmpty ||
            item.displayName.localizedCaseInsensitiveContains(searchText) ||
            item.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var selectedItem: ShortcutItem? {
        items.first { $0.url == selectedItemID }
    }

    var body: some View {
        HSplitView {
            // 左侧：列表
            VStack(spacing: 0) {
                // 工具栏
                HStack(spacing: Spacing.xs) {
                    // 搜索框
                    NeoInput(placeholder: "搜索快捷键配置...", text: $searchText, isSearch: true)

                    NeoButton(title: "导入预设", systemImage: "plus", style: .primary, size: .sm) {
                        chooseAndImportPreset()
                    }

                    NeoButton(title: "", systemImage: "arrow.clockwise", style: .ghost, size: .sm) {
                        runScan()
                    }
                }
                .padding()

                Divider()

                if scanning {
                    VStack(spacing: Spacing.sm) {
                        NeoProgress(value: 0.5)
                        Text("正在扫描快捷键配置...")
                            .font(FontFamily.caption(12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textSecondary)
                        Text("未发现符合条件的快捷键配置")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedItemID) {
                        ForEach(filteredItems) { item in
                            HStack {
                                Image(systemName: "keyboard.fill")
                                    .foregroundColor(Theme.accent)
                                    .font(.system(size: 13, weight: .regular))

                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(item.displayName)
                                        .font(FontFamily.bodyText(13, weight: .medium))
                                    Text(item.name)
                                        .font(FontFamily.caption(12))
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Spacer()

                                Text(DisplayFormat.byteString(item.sizeBytes))
                                    .font(FT.data(12))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .tag(item.url)
                            .padding(.vertical, Spacing.xxxs)
                            .contextMenu {
                                Button("导出此配置...", action: { chooseAndExportPreset(item) })
                                Button("移至废纸篓", role: .destructive, action: { confirmDelete(item) })
                            }
                        }
                    }
                    .listStyle(.inset)
                }
            }
            .frame(minWidth: 450, idealWidth: 600)

            // 右侧：详情面板
            if let item = selectedItem {
                detailPanel(for: item)
                    .frame(width: 320)
                    .frame(maxHeight: .infinity)
                    .background(Theme.panel)
            } else {
                VStack(spacing: Spacing.xs) {
                    Image(systemName: "keyboard")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("请选择快捷键配置以查看详情")
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(width: 320)
                .frame(maxHeight: .infinity)
                .background(Theme.panel)
            }
        }
        .background(Theme.background)
        .onAppear {
            runScan()
        }
        .alert("确定要删除吗？", isPresented: $showingDeleteAlert, presenting: pendingDeleteItem) { item in
            Button("删除", role: .destructive) {
                performDelete(item)
            }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("将安全地把「\(item.displayName)」快捷键预设文件移至系统废纸篓。")
        }
    }

    // MARK: - 详情视图

    private func detailPanel(for item: ShortcutItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "keyboard.onehanded.left.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(Theme.accent)

                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                        Text(item.displayName)
                            .font(FontFamily.heading(20))
                        Text(".fcpxcmd 配置文件")
                            .font(FontFamily.caption(12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }

                Divider()

                Group {
                    infoRow(label: "文件大小", value: DisplayFormat.byteString(item.sizeBytes), isData: true)
                    if let date = item.modifiedAt {
                        infoRow(label: "修改时间", value: DisplayFormat.dateString(date), isData: true)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text("文件路径")
                        .font(FontFamily.caption(12))
                        .foregroundStyle(Theme.textSecondary)
                    Text(item.url.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                Divider()

                // 使用说明
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text("如何在 FCPX 中使用此配置？")
                        .font(FontFamily.bodyText(13, weight: .bold))
                        .foregroundStyle(Theme.accent)

                    Text("1. 在 FCPX 顶部菜单栏选择「Final Cut Pro」->「命令集」 (Command Sets)。")
                    Text("2. 从列表中选择「\(item.displayName)」即可激活对应的键盘快捷键布局。")
                    Text("3. 如果需要修改，可在命令集子菜单中选择「自定」 (Customize)。")
                }
                .font(FontFamily.caption(12))
                .foregroundStyle(Theme.textSecondary)
                .padding(Spacing.xxs)
                .background(Theme.background)

                Spacer()

                HStack(spacing: Spacing.xs) {
                    NeoButton(
                        title: "导出此配置...",
                        style: .secondary,
                        size: .md
                    ) {
                        chooseAndExportPreset(item)
                    }

                    NeoButton(
                        title: "移至废纸篓",
                        style: .destructive,
                        size: .md
                    ) {
                        confirmDelete(item)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
    }

    private func infoRow(label: String, value: String, isData: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(FontFamily.caption(12))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(isData ? FT.data(13, weight: .medium) : FontFamily.bodyText(13, weight: .medium))
        }
    }

    // MARK: - 逻辑

    private func runScan() {
        scanning = true
        errorMessage = nil
        Task {
            let result = scanner.scan()
            await MainActor.run {
                self.items = result
                self.scanning = false
            }
        }
    }

    private func chooseAndImportPreset() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.propertyList, .init(filenameExtension: "fcpxcmd") ?? .data]
        panel.prompt = "导入"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                _ = try scanner.importPreset(from: url)
                runScan()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func chooseAndExportPreset(_ item: ShortcutItem) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "导出到此目录"

        if panel.runModal() == .OK, let url = panel.url {
            do {
                try scanner.exportPreset(item, to: url)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func confirmDelete(_ item: ShortcutItem) {
        pendingDeleteItem = item
        showingDeleteAlert = true
    }

    private func performDelete(_ item: ShortcutItem) {
        do {
            try scanner.deletePreset(item)
            if let idx = items.firstIndex(where: { $0.url == item.url }) {
                items.remove(at: idx)
            }
            if selectedItemID == item.url {
                selectedItemID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
