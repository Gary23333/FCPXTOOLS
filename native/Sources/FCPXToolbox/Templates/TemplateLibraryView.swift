import SwiftUI

struct TemplateLibraryView: View {
    @ObservedObject var model: TemplateLibraryViewModel
    @State private var itemPendingDelete: TemplateItem?

    private let columns = [GridItem(.adaptive(minimum: 168), spacing: 14)]

    var body: some View {
        HStack(spacing: 0) {
            categoryRail
            Divider()
            gridArea
            if model.selectedItem != nil {
                Divider()
                TemplateDetailView(item: model.selectedItem!, onDelete: { item in
                    itemPendingDelete = item
                })
                    .frame(width: 300)
            }
        }
        .background(Theme.background)
        .onAppear { model.scanIfNeeded() }
        .confirmationDialog("删除这个模板？", isPresented: deleteConfirmationBinding, titleVisibility: .visible) {
            Button("移到废纸篓", role: .destructive) {
                if let item = itemPendingDelete {
                    model.delete(item)
                }
                itemPendingDelete = nil
            }
            Button("取消", role: .cancel) {
                itemPendingDelete = nil
            }
        } message: {
            if let item = itemPendingDelete {
                Text("将「\(item.displayName)」移到废纸篓。此操作不会永久删除，可从废纸篓恢复。")
            }
        }
        .alert("模板操作失败", isPresented: errorAlertBinding) {
            Button("好", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: - 分类导航

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("模板分类")
                .font(FontFamily.caption(12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 12).padding(.top, 12)
            Button {
                model.selectedCategory = nil
            } label: {
                HStack {
                    Label("全部模板", systemImage: "square.grid.2x2")
                        .foregroundStyle(model.selectedCategory == nil ? Theme.accent : Theme.textPrimary)
                    Spacer()
                    Text("\(model.allCount)")
                        .font(FT.data(11))
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(model.selectedCategory == nil ? Theme.accent.opacity(0.12) : .clear)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            ForEach(TemplateCategory.allCases) { cat in
                Button {
                    model.selectedCategory = cat
                } label: {
                    HStack {
                        Label(cat.displayName, systemImage: cat.systemImage)
                            .foregroundStyle(model.selectedCategory == cat ? Theme.accent : Theme.textPrimary)
                        Spacer()
                        Text("\(model.count(cat))")
                            .font(FT.data(11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(model.selectedCategory == cat ? Theme.accent.opacity(0.12) : .clear)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 8)
            }
            Spacer()
            Button {
                model.scan()
            } label: {
                Label("重新扫描", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
            .padding(12)
            .disabled(model.scanning)
        }
        .frame(width: 184)
    }

    // MARK: - 网格

    private var gridArea: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    NeoInput(placeholder: "搜索模板名 / 厂商…", text: $model.searchText, isSearch: true)
                    Spacer()
                    Text(model.statusText)
                        .font(FontFamily.caption(12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                filterBar
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()

            if model.scanning && model.items.isEmpty {
                loading
            } else if model.visibleItems.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(model.visibleItems) { item in
                            card(item)
                        }
                    }
                    .padding(16)
                }
                Divider()
                paginationBar
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(_ item: TemplateItem) -> some View {
        let selected = model.selectedItemID == item.id
        return VStack(alignment: .leading, spacing: 6) {
            ThumbnailView(url: item.posterURL, isDarkBackground: item.category == .titles)
                .frame(height: 104)
                .frame(maxWidth: .infinity)
                .clipShape(Rectangle())
                .overlay(alignment: .topTrailing) {
                    HStack(spacing: 4) {
                        if item.isWritable {
                            deleteButton(item)
                        }
                        NeoBadge(text: item.root.rawValue, style: .neutral)
                    }
                    .padding(5)
                }
            Text(item.displayName)
                .font(FontFamily.bodyText(12, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1).truncationMode(.middle)
            Text(item.group)
                .font(FontFamily.caption(11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(DisplayFormat.byteString(item.bytes))
                Text(DisplayFormat.dateString(item.modifiedAt))
            }
            .font(FT.data(11))
            .foregroundStyle(Theme.textSecondary)
            .lineLimit(1)
        }
        .padding(8)
        .background(Theme.panel)
        .clipShape(Rectangle())
        .overlay(
            Rectangle()
                .stroke(selected ? Theme.accent : Theme.border, lineWidth: selected ? 2 : ShapeToken.borderWidth)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            model.selectedItemID = item.id
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            groupMenu
            .frame(maxWidth: 180)

            sizeMenu
            .frame(maxWidth: 150)

            modifiedMenu
            .frame(maxWidth: 150)

            sourceMenu
            .frame(maxWidth: 130)

            if model.activeFilterCount > 0 || !model.searchText.isEmpty {
                Button {
                    model.resetFilters()
                } label: {
                    Label("重置", systemImage: "xmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
            }

            Spacer()
            Text("显示 \(model.filteredItems.count) 项")
                .font(FontFamily.caption(12))
                .foregroundStyle(Theme.textSecondary)
        }
        .font(FontFamily.caption(12))
    }

    private var groupMenu: some View {
        Menu {
            ForEach(model.groupOptions, id: \.self) { group in
                Button(group) { model.selectedGroup = group }
            }
        } label: {
            filterMenuLabel(title: "厂商", value: model.selectedGroup)
        }
        .buttonStyle(.plain)
    }

    private var sizeMenu: some View {
        Menu {
            ForEach(TemplateSizeRange.allCases) { range in
                Button(range.rawValue) { model.sizeRange = range }
            }
        } label: {
            filterMenuLabel(title: "大小", value: model.sizeRange.rawValue)
        }
        .buttonStyle(.plain)
    }

    private var modifiedMenu: some View {
        Menu {
            ForEach(TemplateModifiedRange.allCases) { range in
                Button(range.rawValue) { model.modifiedRange = range }
            }
        } label: {
            filterMenuLabel(title: "修改时间", value: model.modifiedRange.rawValue)
        }
        .buttonStyle(.plain)
    }

    private var sourceMenu: some View {
        Menu {
            ForEach(TemplateRootFilter.allCases) { source in
                Button(source.rawValue) { model.rootFilter = source }
            }
        } label: {
            filterMenuLabel(title: "来源", value: model.rootFilter.rawValue)
        }
        .buttonStyle(.plain)
    }

    private func filterMenuLabel(title: String, value: String) -> some View {
        HStack(spacing: 5) {
            Text(title)
                .foregroundStyle(Theme.textSecondary)
            Text(value)
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 2)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
        }
        .font(FontFamily.caption(12, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.panel)
        .overlay(
            Rectangle()
                .stroke(Theme.border, lineWidth: ShapeToken.borderWidth)
        )
    }

    private var paginationBar: some View {
        HStack(spacing: 10) {
            Text("每页 \(model.pageSize) 项")
                .font(FontFamily.caption(12))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
            pagerButton("首页", systemImage: "backward.end.fill", enabled: model.canGoPreviousPage) {
                model.goToFirstPage()
            }
            pagerButton("上一页", systemImage: "chevron.left", enabled: model.canGoPreviousPage) {
                model.goToPreviousPage()
            }
            Text("第 \(model.currentPage) / \(model.totalPages) 页 · \(model.pageRangeText)")
                .font(FontFamily.caption(12, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .frame(minWidth: 150)
            pagerButton("下一页", systemImage: "chevron.right", enabled: model.canGoNextPage) {
                model.goToNextPage()
            }
            pagerButton("末页", systemImage: "forward.end.fill", enabled: model.canGoNextPage) {
                model.goToLastPage()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.background)
    }

    private func pagerButton(_ title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .labelStyle(.iconOnly)
                .frame(width: 28, height: 24)
                .foregroundStyle(enabled ? Theme.accent : Theme.textSecondary)
                .background(Theme.panel)
                .overlay(
                    Rectangle()
                        .stroke(Theme.border, lineWidth: ShapeToken.borderWidth)
                )
                .opacity(enabled ? 1 : 0.42)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .help(title)
    }

    private func deleteButton(_ item: TemplateItem) -> some View {
        Button {
            itemPendingDelete = item
        } label: {
            Image(systemName: "trash")
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 18)
                .background(Theme.danger.opacity(0.9))
                .foregroundStyle(.white)
                .clipShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

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

    private var loading: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView().controlSize(.large)
            Text(model.statusText).font(FontFamily.caption(12)).foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.textSecondary)
            Text(model.searchText.isEmpty ? "没有符合筛选条件的模板" : "没有匹配「\(model.searchText)」的模板")
                .font(FontFamily.bodyText(14))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
