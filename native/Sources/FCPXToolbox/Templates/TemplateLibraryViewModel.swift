import SwiftUI
import Combine

@MainActor
final class TemplateLibraryViewModel: ObservableObject {
    @Published private(set) var items: [TemplateItem] = []
    @Published var scanning = false
    @Published var hasScanned = false
    @Published var statusText = "准备扫描模板库…"
    @Published var totalBytes: Int64 = 0

    @Published var selectedCategory: TemplateCategory? = nil {
        didSet { applyFilter() }
    }
    @Published var searchText = "" {
        didSet { scheduleFilter() }
    }
    @Published var selectedGroup = "全部厂商" {
        didSet { applyFilter() }
    }
    @Published var sizeRange: TemplateSizeRange = .all {
        didSet { applyFilter() }
    }
    @Published var modifiedRange: TemplateModifiedRange = .all {
        didSet { applyFilter() }
    }
    @Published var rootFilter: TemplateRootFilter = .all {
        didSet { applyFilter() }
    }
    @Published var selectedItemID: TemplateItem.ID?
    @Published var errorMessage: String?

    /// 过滤后的完整结果（缓存，避免每次 body 重算）。
    @Published private(set) var filteredItems: [TemplateItem] = []
    /// 当前实际渲染的分页切片。
    @Published private(set) var visibleItems: [TemplateItem] = []
    @Published private(set) var currentPage = 1

    private var counts: [TemplateCategory: Int] = [:]
    let pageSize = 50
    private var searchDebounce: Task<Void, Never>?

    private let scanner = TemplateScanner()

    var allCount: Int { items.count }
    var totalPages: Int { max(1, Int(ceil(Double(filteredItems.count) / Double(pageSize)))) }
    var pageRangeText: String {
        guard !filteredItems.isEmpty else { return "0 / 0" }
        let start = (currentPage - 1) * pageSize + 1
        let end = min(currentPage * pageSize, filteredItems.count)
        return "\(start)-\(end) / \(filteredItems.count)"
    }
    var canGoPreviousPage: Bool { currentPage > 1 }
    var canGoNextPage: Bool { currentPage < totalPages }
    var groupOptions: [String] {
        let groups = items
            .filter { selectedCategory == nil || $0.category == selectedCategory }
            .map(\.group)
        return ["全部厂商"] + Array(Set(groups)).sorted()
    }
    var activeFilterCount: Int {
        var count = 0
        if selectedGroup != "全部厂商" { count += 1 }
        if sizeRange != .all { count += 1 }
        if modifiedRange != .all { count += 1 }
        if rootFilter != .all { count += 1 }
        return count
    }

    func scanIfNeeded() {
        guard !hasScanned, !scanning else { return }
        scan()
    }

    func scan() {
        scanning = true
        hasScanned = true
        items = []
        filteredItems = []
        visibleItems = []
        currentPage = 1
        counts = [:]
        totalBytes = 0
        selectedItemID = nil
        selectedGroup = "全部厂商"
        sizeRange = .all
        modifiedRange = .all
        rootFilter = .all
        errorMessage = nil
        statusText = "扫描中…"

        Task.detached(priority: .userInitiated) { [scanner] in
            // 后台串行回调，按时间窗批量推送，边扫边显示，避免一次性等待全部测量完成。
            var batch: [TemplateItem] = []
            var lastFlush = Date.distantPast
            func flush(force: Bool) {
                guard force || Date().timeIntervalSince(lastFlush) > 0.12 else { return }
                lastFlush = Date()
                let toSend = batch
                batch = []
                Task { @MainActor in self.ingest(toSend) }
            }

            let result = scanner.scan(progress: { p in
                Task { @MainActor in
                    self.statusText = "发现 \(p.discovered) 个模板 · \(DisplayFormat.byteString(p.totalBytes))"
                    self.totalBytes = p.totalBytes
                }
            }, itemFound: { item in
                batch.append(item)
                flush(force: false)
            })

            let tail = batch
            await MainActor.run {
                self.ingest(tail)
                // 收尾：用排序后的完整结果替换，保证稳定顺序。
                self.items = result.items
                self.counts = Dictionary(grouping: result.items, by: \.category).mapValues(\.count)
                self.totalBytes = result.totalBytes
                self.scanning = false
                self.statusText = String(format: "共 %d 个模板 · %@ · 用时 %.1fs",
                                         result.items.count,
                                         DisplayFormat.byteString(result.totalBytes),
                                         result.duration)
                self.applyFilter()
            }
        }
    }

    /// 增量并入一批扫描结果并刷新当前分类视图（节流后调用）。
    private func ingest(_ batch: [TemplateItem]) {
        guard !batch.isEmpty else { return }
        items.append(contentsOf: batch)
        for item in batch { counts[item.category, default: 0] += 1 }
        applyFilter()
    }

    /// 各分类模板数量（扫描后一次性算好，O(1) 读取）。
    func count(_ category: TemplateCategory) -> Int {
        counts[category] ?? 0
    }

    func resetFilters() {
        searchText = ""
        selectedGroup = "全部厂商"
        sizeRange = .all
        modifiedRange = .all
        rootFilter = .all
        applyFilter()
    }

    func goToFirstPage() {
        setPage(1)
    }

    func goToPreviousPage() {
        setPage(currentPage - 1)
    }

    func goToNextPage() {
        setPage(currentPage + 1)
    }

    func goToLastPage() {
        setPage(totalPages)
    }

    private func setPage(_ page: Int) {
        currentPage = min(max(page, 1), totalPages)
        refreshVisible()
        if let id = selectedItemID, !visibleItems.contains(where: { $0.id == id }) {
            selectedItemID = visibleItems.first?.id
        } else if selectedItemID == nil {
            selectedItemID = visibleItems.first?.id
        }
    }

    func delete(_ item: TemplateItem) {
        guard item.isWritable, !scanning else { return }
        statusText = "正在移到废纸篓：\(item.displayName)"
        Task.detached(priority: .userInitiated) {
            do {
                try FileMover.trash(item.folderURL)
                await MainActor.run {
                    self.items.removeAll { $0.id == item.id }
                    self.counts = Dictionary(grouping: self.items, by: \.category).mapValues(\.count)
                    self.totalBytes = self.items.reduce(0) { $0 + $1.bytes }
                    if self.selectedItemID == item.id {
                        self.selectedItemID = nil
                    }
                    if !self.groupOptions.contains(self.selectedGroup) {
                        self.selectedGroup = "全部厂商"
                    }
                    self.statusText = "已移到废纸篓：\(item.displayName)"
                    self.applyFilter()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "删除失败：\(error.localizedDescription)"
                    self.statusText = "删除失败"
                }
            }
        }
    }

    // MARK: - 过滤 + 分页

    private func scheduleFilter() {
        searchDebounce?.cancel()
        searchDebounce = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000) // 180ms 防抖
            guard !Task.isCancelled else { return }
            applyFilter()
        }
    }

    private func applyFilter() {
        if !groupOptions.contains(selectedGroup) {
            selectedGroup = "全部厂商"
        }

        let now = Date()
        var base = items.filter {
            (selectedCategory == nil || $0.category == selectedCategory)
                && (selectedGroup == "全部厂商" || $0.group == selectedGroup)
                && sizeRange.matches($0.bytes)
                && modifiedRange.matches($0.modifiedAt, now: now)
                && rootFilter.matches($0.root)
        }
        let q = searchText.trimmingCharacters(in: .whitespaces)
        if !q.isEmpty {
            base = base.filter {
                $0.displayName.localizedCaseInsensitiveContains(q)
                    || $0.group.localizedCaseInsensitiveContains(q)
                    || $0.folderName.localizedCaseInsensitiveContains(q)
            }
        }
        filteredItems = base
        currentPage = 1
        refreshVisible()
        if let id = selectedItemID, !visibleItems.contains(where: { $0.id == id }) {
            selectedItemID = visibleItems.first?.id
        } else if selectedItemID == nil {
            selectedItemID = visibleItems.first?.id
        }
    }

    private func refreshVisible() {
        currentPage = min(max(currentPage, 1), totalPages)
        let start = (currentPage - 1) * pageSize
        let end = min(start + pageSize, filteredItems.count)
        visibleItems = start < end ? Array(filteredItems[start..<end]) : []
    }

    var selectedItem: TemplateItem? {
        guard let id = selectedItemID else { return nil }
        return items.first { $0.id == id }
    }
}
