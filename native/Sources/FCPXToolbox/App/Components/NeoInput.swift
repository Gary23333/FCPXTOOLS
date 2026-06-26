import SwiftUI

/// 21th 风格搜索/文本输入框。零圆角、2px 边框、偏移阴影。
struct NeoInput: View {
    let placeholder: String
    @Binding var text: String
    var isSearch: Bool = false

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: Spacing.xxs) {
            if isSearch {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
            }

            TextField(placeholder, text: $text)
                .font(FontFamily.bodyText(14))
                .foregroundStyle(Theme.textPrimary)
                .textFieldStyle(.plain)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.xxs)
        .padding(.vertical, 8)
        .background(Theme.panel)
        .overlay(
            Rectangle()
                .stroke(isFocused ? Theme.accent : Theme.border, lineWidth: ShapeToken.borderWidth)
        )
        .neoShadow(.small)
    }
}
