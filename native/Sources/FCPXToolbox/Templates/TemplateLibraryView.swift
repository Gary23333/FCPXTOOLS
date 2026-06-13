import SwiftUI

struct TemplateLibraryView: View {
    @StateObject private var model = TemplateLibraryViewModel()

    private let columns = [GridItem(.adaptive(minimum: 168, maximum: 220), spacing: 14)]

    var body: some View {
        HStack(spacing: 0) {
            categoryRail
            Divider()
            gridArea
            if model.selectedItem != nil {
                Divider()
                TemplateDetailView(item: model.selectedItem!)
                    .frame(width: 300)
            }
        }
        .background(Theme.background)
        .onAppear { model.scanIfNeeded() }
    }

    // MARK: - 分类导航

    private var categoryRail: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("模板分类")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 12).padding(.top, 12)
            ForEach(TemplateCategory.allCases) { cat in
                Button {
                    model.selectedCategory = cat
                } label: {
                    HStack {
                        Label(cat.displayName, systemImage: cat.systemImage)
                            .foregroundStyle(model.selectedCategory == cat ? Theme.accent : Theme.textPrimary)
                        Spacer()
                        Text("\(model.count(cat))")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(model.selectedCategory == cat ? Theme.accent.opacity(0.12) : .clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
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
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Theme.textSecondary)
                TextField("搜索模板名 / 厂商…", text: $model.searchText)
                    .textFieldStyle(.plain)
                Spacer()
                Text(model.statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
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
                                .onAppear { model.loadMoreIfNeeded(currentItem: item) }
                        }
                    }
                    .padding(16)

                    if model.canLoadMore {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text("加载更多… 已显示 \(model.visibleItems.count) / \(model.filteredItems.count)")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.bottom, 16)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func card(_ item: TemplateItem) -> some View {
        let selected = model.selectedItemID == item.id
        return Button {
            model.selectedItemID = item.id
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                ThumbnailView(url: item.posterURL)
                    .frame(height: 104)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .topTrailing) {
                        if item.root == .system {
                            Text("系统")
                                .font(.system(size: 9, weight: .semibold))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(.black.opacity(0.55))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .padding(5)
                        }
                    }
                Text(item.displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1).truncationMode(.middle)
                Text(item.group)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
            }
            .padding(8)
            .background(Theme.panel)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(selected ? Theme.accent : Theme.line, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var loading: some View {
        VStack(spacing: 10) {
            Spacer()
            ProgressView().controlSize(.large)
            Text(model.statusText).font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 34)).foregroundStyle(Theme.textSecondary)
            Text(model.searchText.isEmpty ? "此分类暂无模板" : "没有匹配「\(model.searchText)」的模板")
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
