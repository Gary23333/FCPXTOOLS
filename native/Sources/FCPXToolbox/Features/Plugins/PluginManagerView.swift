import SwiftUI

/// FxPlug 插件管理器视图。
struct PluginManagerView: View {
    @State private var items: [PluginItem] = []
    @State private var searchText = ""
    @State private var selectedLocation: PluginLocationFilter = .all
    @State private var selectedItemID: URL?
    @State private var scanning = false
    @State private var errorMessage: String?
    @State private var showingDeleteAlert = false
    @State private var pendingDeleteItem: PluginItem?

    private let scanner = PluginScanner()

    enum PluginLocationFilter: String, CaseIterable, Identifiable {
        case all = "全部位置"
        case user = "用户目录"
        case system = "系统目录"

        var id: String { rawValue }
    }

    var filteredItems: [PluginItem] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.displayName.localizedCaseInsensitiveContains(searchText) ||
                item.name.localizedCaseInsensitiveContains(searchText)

            let matchesLocation: Bool
            switch selectedLocation {
            case .all: matchesLocation = true
            case .user: matchesLocation = item.location == .user
            case .system: matchesLocation = item.location == .system
            }

            return matchesSearch && matchesLocation
        }
    }

    var selectedItem: PluginItem? {
        items.first { $0.url == selectedItemID }
    }

    var body: some View {
        HSplitView {
            // 左侧：列表与过滤
            VStack(spacing: 0) {
                // 工具栏
                HStack(spacing: Spacing.xs) {
                    // 搜索框
                    NeoInput(placeholder: "搜索插件...", text: $searchText, isSearch: true)

                    // 位置过滤
                    Picker("位置", selection: $selectedLocation) {
                        ForEach(PluginLocationFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    NeoButton(title: "", systemImage: "arrow.clockwise", style: .ghost, size: .sm) {
                        runScan()
                    }
                }
                .padding()

                Divider()

                if scanning {
                    VStack(spacing: Spacing.sm) {
                        NeoProgress(value: 0.5)
                        Text("正在扫描插件...")
                            .font(FT.label())
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if filteredItems.isEmpty {
                    VStack(spacing: Spacing.xs) {
                        Image(systemName: "puzzlepiece")
                            .font(FT.metric())
                            .foregroundStyle(Theme.textSecondary)
                        Text("未发现符合条件的插件")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedItemID) {
                        ForEach(filteredItems) { item in
                            HStack {
                                Image(systemName: item.isEnabled ? "puzzlepiece.fill" : "puzzlepiece")
                                    .foregroundColor(item.isEnabled ? Theme.accent : Theme.textSecondary)
                                    .font(FT.data())

                                VStack(alignment: .leading, spacing: Spacing.xs) {
                                    Text(item.displayName)
                                        .font(FT.data(13, weight: .medium))
                                    Text(item.name)
                                        .font(FT.label())
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Spacer()

                                Text(DisplayFormat.byteString(item.sizeBytes))
                                    .font(FT.label())
                                    .foregroundStyle(Theme.textSecondary)

                                Toggle("", isOn: Binding(
                                    get: { item.isEnabled },
                                    set: { newValue in
                                        togglePlugin(item, to: newValue)
                                    }
                                ))
                                .toggleStyle(.switch)
                                .scaleEffect(0.8)
                            }
                            .tag(item.url)
                            .padding(.vertical, Spacing.xxxs)
                            .contextMenu {
                                Button("移至废纸篓", role: .destructive) {
                                    confirmDelete(item)
                                }
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
                    .background(Theme.panel)
            } else {
                VStack {
                    Text("请选择插件以查看详情")
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
        .alert("确定要删除插件吗？", isPresented: $showingDeleteAlert, presenting: pendingDeleteItem) { item in
            Button("删除", role: .destructive) {
                performDelete(item)
            }
            Button("取消", role: .cancel) {}
        } message: { item in
            Text("将安全地把「\(item.displayName)」移至系统废纸篓。")
        }
    }

    // MARK: - 详情视图

    private func detailPanel(for item: PluginItem) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(FT.metric())
                        .foregroundColor(Theme.accent)

                    VStack(alignment: .leading, spacing: Spacing.xxxs) {
                        Text(item.displayName)
                            .font(FT.title())
                            .fontWeight(.bold)
                        NeoBadge(
                            text: item.isEnabled ? "启用中" : "已禁用",
                            style: item.isEnabled ? .safe : .danger
                        )
                    }
                }

                Divider()

                Group {
                    infoRow(label: "类型", value: item.type.rawValue)
                    infoRow(label: "位置", value: item.location.rawValue)
                    infoRow(label: "大小", value: DisplayFormat.byteString(item.sizeBytes))
                    infoRow(label: "文件名", value: item.name)
                }

                Divider()

                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text("完整路径")
                        .font(FT.label())
                        .foregroundStyle(Theme.textSecondary)
                    Text(item.url.path)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                Spacer()

                HStack(spacing: Spacing.xs) {
                    NeoButton(
                        title: item.isEnabled ? "禁用插件" : "启用插件",
                        style: .secondary,
                        size: .md
                    ) {
                        togglePlugin(item, to: !item.isEnabled)
                    }
                    .frame(maxWidth: .infinity)

                    NeoButton(
                        title: "删除插件",
                        style: .destructive,
                        size: .md
                    ) {
                        confirmDelete(item)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding()
        }
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(FT.data())
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

    private func togglePlugin(_ item: PluginItem, to newValue: Bool) {
        guard item.isEnabled != newValue else { return }

        do {
            let newURL = try scanner.togglePlugin(item)

            // 更新本地数据列表
            if let idx = items.firstIndex(where: { $0.url == item.url }) {
                items[idx] = PluginItem(
                    url: newURL,
                    name: items[idx].name,
                    displayName: items[idx].displayName,
                    type: items[idx].type,
                    location: items[idx].location,
                    sizeBytes: items[idx].sizeBytes,
                    isEnabled: newValue
                )

                // 如果当前选中的是被修改的插件，更新选中的 ID
                if selectedItemID == item.url {
                    selectedItemID = newURL
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func confirmDelete(_ item: PluginItem) {
        pendingDeleteItem = item
        showingDeleteAlert = true
    }

    private func performDelete(_ item: PluginItem) {
        do {
            try scanner.deletePlugin(item)
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
