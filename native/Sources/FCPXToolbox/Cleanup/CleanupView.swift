import SwiftUI

struct CleanupView: View {
    @ObservedObject var model: CleanupViewModel
    @State private var showCleanConfirm = false
    @State private var showResult = false

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
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(.system(size: 26))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("FCPX 清理助手")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(model.rootURL?.path ?? "选择包含 Final Cut Pro 资源库的目录开始扫描")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer()
            Button("选择目录") { model.chooseDirectory() }
                .disabled(model.isBusy)
            Button("重新扫描") { model.rescan() }
                .disabled(!model.canRescan)
            Button("停止") { model.stopScan() }
                .disabled(model.phase != .scanning)
            Button("选择全部安全项") { model.selectAllSafe() }
                .disabled(!model.canSelectSafe)
            Button("清理所选") { showCleanConfirm = true }
                .disabled(!model.canClean)
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
        }
    }

    // MARK: - 统计卡片

    private var summaryCards: some View {
        HStack(spacing: 10) {
            summaryCard("项目总占用", DisplayFormat.byteString(model.totalBytes), Theme.textPrimary)
            summaryCard("可清理空间", DisplayFormat.byteString(model.cleanableBytes), Theme.accent)
            summaryCard("已选清理", DisplayFormat.byteString(model.selectedBytes), Theme.textPrimary)
            summaryCard("资源库/项目", "\(model.projects.count)", Theme.textPrimary)
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
            VStack(alignment: .leading, spacing: 8) {
                Text("资源库 / 项目")
                    .font(.system(size: 15, weight: .semibold))
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
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                            }
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
            Image(systemName: "folder.badge.questionmark")
                .font(.system(size: 34))
                .foregroundStyle(Theme.textSecondary)
            Text("选择 Final Cut Pro 资源库所在目录")
                .foregroundStyle(Theme.textSecondary)
            Text("扫描后可查看每个资源库的总占用和可清理缓存。")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func projectRow(_ project: ResourceItem) -> some View {
        HStack(spacing: 10) {
            Button {
                model.toggleProject(project)
            } label: {
                Image(systemName: project.selectedBytes > 0 ? "checkmark.square.fill" : "square")
                    .foregroundStyle(project.cleanableBytes > 0 ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(project.cleanableBytes == 0)

            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(project.kind.rawValue) · \(DisplayFormat.dateString(project.modifiedAt))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(DisplayFormat.byteString(project.totalBytes))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.textPrimary)
                Text("可清理 \(DisplayFormat.byteString(project.cleanableBytes))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private var detailPanel: some View {
        Card {
            Group {
                if let project = model.selectedProject {
                    detailContent(project)
                } else {
                    VStack(spacing: 6) {
                        Spacer()
                        Text("未选择项目").font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("扫描后选择一个资源库查看详情")
                            .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(14)
        }
    }

    private func detailContent(_ project: ResourceItem) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(project.name).font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(project.kind.rawValue) · \(project.url.path)")
                        .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                        .lineLimit(1).truncationMode(.middle)
                }
                Spacer()
                Button("在 Finder 显示") {
                    NSWorkspace.shared.activateFileViewerSelecting([project.url])
                }
            }

            HStack(spacing: 18) {
                statPair("总占用", DisplayFormat.byteString(project.totalBytes), Theme.textPrimary)
                statPair("可清理", DisplayFormat.byteString(project.cleanableBytes), Theme.accent)
                statPair("已选", DisplayFormat.byteString(project.selectedBytes), Theme.textPrimary)
                statPair("原始素材", DisplayFormat.byteString(project.originalMediaBytes), Theme.textSecondary)
            }

            Divider()
            Text("可清理项").font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)

            ScrollView {
                VStack(spacing: 6) {
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
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            Text(value).font(.system(size: 16, weight: .semibold)).foregroundStyle(color)
        }
    }

    private func cacheRow(_ group: CacheGroup) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Button {
                model.toggleGroup(group)
            } label: {
                Image(systemName: group.isSelected ? "checkmark.square.fill" : "square")
                    .foregroundStyle(group.canClean ? Theme.accent : Theme.textSecondary)
            }
            .buttonStyle(.plain)
            .disabled(!group.canClean)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(group.title).font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.textPrimary)
                    Text(group.risk.rawValue)
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Theme.riskColor(group.risk).opacity(0.14))
                        .foregroundStyle(Theme.riskColor(group.risk))
                        .clipShape(Capsule())
                }
                Text(group.explanation)
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(DisplayFormat.byteString(group.bytes))
                    .font(.system(size: 13)).foregroundStyle(Theme.textPrimary)
                Text("\(group.fileCount) 个文件")
                    .font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(10)
        .background(Theme.background)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    // MARK: - 状态栏

    private var statusBar: some View {
        VStack(spacing: 6) {
            ProgressView(value: model.progressValue)
                .tint(Theme.accent)
            HStack {
                Text(model.statusText)
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
                Spacer()
                Text(model.progressText)
                    .font(.system(size: 12)).foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
