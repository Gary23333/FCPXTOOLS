import SwiftUI

struct CleanupView: View {
    @EnvironmentObject private var appState: AppState
    @ObservedObject var model: CleanupViewModel
    @State private var showCleanConfirm = false
    @State private var showResult = false

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
        .onChange(of: appState.globalProjectDir) {
            if let newDir = appState.globalProjectDir, model.rootURL != newDir {
                model.rootURL = newDir
                model.rescan()
            }
        }
        .onChange(of: model.rootURL) {
            if model.rootURL != appState.globalProjectDir {
                appState.globalProjectDir = model.rootURL
            }
        }
        .confirmationDialog("确认清理所选缓存？", isPresented: $showCleanConfirm, titleVisibility: .visible) {
            Button("移到废纸篓", role: .destructive) {
                model.performClean()
                showResult = true
            }
            Button("取消", role: .cancel) {}
        } message: {
            if let s = model.cleanSummary() {
                let risky = s.riskyTitles.isEmpty ? "" : "\n包含需确认项目：\(s.riskyTitles.joined(separator: "、"))。"
                Text("将 \(s.count) 个目录移到废纸篓，预计释放 \(DisplayFormat.byteString(s.bytes))。\(risky)\n\n移到废纸篓，不会永久删除。")
            }
        }
        .alert("清理完成", isPresented: $showResult, presenting: model.lastResult) { _ in
            Button("好", role: .cancel) {}
        } message: { result in
            Text("已移到废纸篓：\(result.succeeded) 项，释放 \(DisplayFormat.byteString(result.cleanedBytes))。\n失败：\(result.failed.count) 项。")
        }
    }

    // MARK: - 工具栏

    private var toolbar: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            NeoSectionHeader(
                systemImage: "sparkles",
                title: "FCPX 清理助手",
                subtitle: model.rootURL?.path ?? "选择包含 Final Cut Pro 资源库的目录开始扫描"
            )

            HStack(spacing: Spacing.xxs) {
                NeoButton(title: "选择目录", systemImage: "folder.badge.plus", style: .secondary, size: .sm, isEnabled: !model.isBusy) {
                    model.chooseDirectory()
                }
                NeoButton(title: "重新扫描", systemImage: "arrow.clockwise", style: .secondary, size: .sm, isEnabled: model.canRescan) {
                    model.rescan()
                }
                NeoButton(title: "停止", systemImage: "stop.circle", style: .secondary, size: .sm, isEnabled: model.phase == .scanning) {
                    model.stopScan()
                }
                NeoButton(title: "选择安全项", systemImage: "checkmark.square", style: .secondary, size: .sm, isEnabled: model.canSelectSafe) {
                    model.selectAllSafe()
                }
                NeoButton(title: "清理所选", systemImage: "trash", style: .primary, size: .sm, isEnabled: model.canClean) {
                    showCleanConfirm = true
                }
            }
        }
    }

    // MARK: - 统计卡片

    private var summaryCards: some View {
        HStack(spacing: Spacing.xxs) {
            summaryCard("项目总占用", DisplayFormat.byteString(model.totalBytes), Theme.textPrimary)
            summaryCard("可清理空间", DisplayFormat.byteString(model.cleanableBytes), Theme.accent)
            summaryCard("已选清理", DisplayFormat.byteString(model.selectedBytes), Theme.textPrimary)
            summaryCard("资源库/项目", "\(model.projects.count)", Theme.textPrimary)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func summaryCard(_ title: String, _ value: String, _ color: Color) -> some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text(title)
                    .font(FontFamily.caption(11))
                    .foregroundStyle(Theme.textSecondary)
                Text(value)
                    .font(FT.metric())
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Spacing.xs)
            .padding(.horizontal, Spacing.xs)
        }
    }

    // MARK: - 主区：列表 + 详情

    private var content: some View {
        HStack(spacing: Spacing.xxs) {
            projectList
                .frame(maxWidth: .infinity)
                .frame(minWidth: 320)
                .layoutPriority(0.35)
            detailPanel
                .frame(maxWidth: .infinity)
                .layoutPriority(0.65)
        }
        .frame(maxHeight: .infinity)
    }

    private var projectList: some View {
        Card {
            VStack(alignment: .leading, spacing: Spacing.xxs) {
                Text("资源库 / 项目")
                    .font(FontFamily.heading(16, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                if model.projects.isEmpty {
                    emptyHint
                } else {
                    List(selection: Binding(
                        get: { model.selectedProjectID },
                        set: { model.selectedProjectID = $0 }
                    )) {
                        ForEach(model.visibleProjects) { project in
                            projectRow(project).tag(project.id)
                                .onAppear { model.loadMoreIfNeeded(currentItem: project) }
                        }
                        if model.canLoadMore {
                            HStack {
                                Spacer()
                                Text("已显示 \(model.visibleProjects.count) / \(model.projects.count)")
                                    .font(FT.data(11))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                            }
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
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textSecondary)
            Text("选择 Final Cut Pro 资源库所在目录")
                .font(FontFamily.bodyText(13))
                .foregroundStyle(Theme.textSecondary)
            Text("扫描后可查看每个资源库的总占用和可清理缓存。")
                .font(FontFamily.caption(11))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectRow(_ project: ResourceItem) -> some View {
        HStack(spacing: Spacing.xxs) {
            Button {
                model.toggleProject(project)
            } label: {
                Image(systemName: project.selectedBytes > 0 ? "checkmark.square.fill" : "square")
                    .foregroundStyle(project.cleanableBytes > 0 ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(project.cleanableBytes == 0)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                Text(project.name)
                    .font(FontFamily.bodyText(13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(project.kind.rawValue) · \(DisplayFormat.dateString(project.modifiedAt))")
                    .font(FT.data(11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xxxs) {
                Text(DisplayFormat.byteString(project.totalBytes))
                    .font(FT.data())
                    .foregroundStyle(Theme.textPrimary)
                Text("可清理 \(DisplayFormat.byteString(project.cleanableBytes))")
                    .font(FT.data(11))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, Spacing.xxxs)
    }

    private var detailPanel: some View {
        Card {
            Group {
                if let project = model.selectedProject {
                    detailContent(project)
                } else {
                    VStack(spacing: Spacing.xxs) {
                        Spacer()
                        Text("未选择项目").font(FontFamily.heading(18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("扫描后选择一个资源库查看详情")
                            .font(FontFamily.caption(11)).foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(Spacing.xs)
        }
    }

    private func detailContent(_ project: ResourceItem) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxxs) {
                    Text(project.name).font(FontFamily.heading(18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(project.kind.rawValue) · \(project.url.path)")
                        .font(FT.label()).foregroundStyle(Theme.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Button("在 Finder 显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([project.url])
                }
            }

            HStack(spacing: Spacing.md) {
                statPair("总占用", DisplayFormat.byteString(project.totalBytes), Theme.textPrimary)
                statPair("可清理", DisplayFormat.byteString(project.cleanableBytes), Theme.accent)
                statPair("已选", DisplayFormat.byteString(project.selectedBytes), Theme.textPrimary)
                statPair("原始素材", DisplayFormat.byteString(project.originalMediaBytes), Theme.textSecondary)
            }

            Divider()
            Text("可清理项").font(FontFamily.heading(16, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ScrollView {
                VStack(spacing: Spacing.xxs) {
                    ForEach(project.cacheGroups) { group in
                        cacheRow(group)
                    }
                }
            }
        }
        .id(model.revision)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func statPair(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xxxs) {
            Text(title).font(FontFamily.caption(11)).foregroundStyle(Theme.textSecondary)
            Text(value).font(FT.data(16, weight: .semibold)).foregroundStyle(color)
        }
    }

    private func cacheRow(_ group: CacheGroup) -> some View {
        HStack(alignment: .top, spacing: Spacing.xxs) {
            Button {
                model.toggleGroup(group)
            } label: {
                Image(systemName: group.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(group.canClean ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!group.canClean)

            VStack(alignment: .leading, spacing: Spacing.xxxs) {
                HStack(spacing: Spacing.xxxs) {
                    Text(group.title).font(FontFamily.bodyText(13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    NeoBadge(
                        text: group.risk.rawValue,
                        style: group.risk == .safe ? .safe : group.risk == .confirm ? .warning : .neutral
                    )
                }
                Text(group.explanation)
                    .font(FontFamily.caption(11)).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: Spacing.xxxs) {
                Text(DisplayFormat.byteString(group.bytes))
                    .font(FT.data(13)).foregroundStyle(Theme.textPrimary)
                Text("\(group.fileCount) 个文件")
                    .font(FT.data(11)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(Spacing.xxs)
        .background(Theme.background)
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: Spacing.xxs) {
            NeoProgress(value: model.progressValue)
            HStack {
                Text(model.statusText)
                    .font(FontFamily.caption(11)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(model.progressText)
                    .font(FT.label(11)).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
