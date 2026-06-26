import SwiftUI

/// 21th 风格进度条。零圆角、2px 边框。
struct NeoProgress: View {
    let value: Double // 0...1

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Rectangle()
                    .fill(Theme.background)

                // Fill
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .frame(height: 6)
        .overlay(
            Rectangle()
                .stroke(Theme.border, lineWidth: ShapeToken.borderWidth)
        )
    }
}
