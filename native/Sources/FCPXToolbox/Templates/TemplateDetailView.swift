import SwiftUI

struct TemplateDetailView: View {
    let item: TemplateItem

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ThumbnailView(url: item.posterURL, maxPixel: 600)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayName)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("\(item.category.displayName) · \(item.group)")
                        .font(.system(size: 12))
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
                    Text("路径").font(.system(size: 11)).foregroundStyle(Theme.textSecondary)
                    Text(item.folderURL.path)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([item.folderURL])
                } label: {
                    Label("在 Finder 显示", systemImage: "folder")
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .background(Theme.panel)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 76, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
