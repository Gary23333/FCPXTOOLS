import SwiftUI

struct TemplateDetailView: View {
    let item: TemplateItem
    var onDelete: ((TemplateItem) -> Void)?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ThumbnailView(url: item.posterURL, maxPixel: 600, isDarkBackground: item.category == .titles)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipShape(Rectangle())
                    .overlay(
                        Rectangle().stroke(Theme.border, lineWidth: ShapeToken.borderWidth)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(FT.data(17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(item.category.displayName) · \(item.group)")
                        .font(FT.data(12))
                        .foregroundStyle(Theme.textSecondary)
                }

                Divider()

                infoRow("分类", item.category.displayName)
                infoRow("厂商 / 主题", item.group)
                infoRow("大小", DisplayFormat.byteString(item.bytes))
                infoRow("修改时间", DisplayFormat.dateString(item.modifiedAt))
                infoRow("来源", item.root.rawValue + (item.isWritable ? "" : "（只读）"))
                infoRow("文件夹名", item.folderName)

                VStack(alignment: .leading, spacing: 3) {
                    Text("路径").font(FT.data(11)).foregroundStyle(Theme.textSecondary)
                    Text(item.folderURL.path)
                        .font(FT.data(11))
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NeoButton(
                    title: "在 Finder 显示",
                    systemImage: "folder",
                    style: .secondary,
                    size: .md
                ) {
                    NSWorkspace.shared.activateFileViewerSelecting([item.folderURL])
                }
                .frame(maxWidth: .infinity)

                if item.isWritable {
                    NeoButton(
                        title: "删除模板",
                        systemImage: "trash",
                        style: .destructive,
                        size: .md
                    ) {
                        onDelete?(item)
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .background(Theme.panel)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(FT.data(12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(FT.data(12))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
