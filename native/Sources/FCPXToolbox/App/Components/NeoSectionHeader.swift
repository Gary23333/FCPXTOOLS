import SwiftUI

/// 21th 风格模块页面标题区域。统一的图标 + 标题 + 副标题布局。
struct NeoSectionHeader: View {
    let systemImage: String
    let title: String
    var subtitle: String = ""

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: systemImage)
                .font(.system(size: 24))
                .foregroundStyle(Theme.accent)
                .frame(width: 36, height: 36)
                .background(Theme.accent.opacity(0.1))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(FT.title(20, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(FT.data(11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer()
        }
    }
}
