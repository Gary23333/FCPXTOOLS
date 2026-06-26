import SwiftUI

/// 21th 风格模块页面标题区域。统一的图标 + 标题 + 副标题布局。
struct NeoSectionHeader: View {
    let systemImage: String
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.1))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(FontFamily.heading(22, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(FontFamily.caption(12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()
        }
    }
}
