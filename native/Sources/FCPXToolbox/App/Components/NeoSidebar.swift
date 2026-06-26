import SwiftUI

/// 21th 风格侧边栏导航。圆点指示器、分组标题、紧凑密度。
struct NeoSidebar: View {
    @Binding var selection: ToolSection

    private var groupedSections: [(String, [ToolSection])] {
        let order: [String] = ["快捷工具", "资源管理", "创作辅助"]
        return order.map { group in
            (group, ToolSection.allCases.filter { $0.group == group })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Brand
            HStack(spacing: Spacing.xxxs) {
                Text("FCPX")
                    .font(FT.brand(14, weight: .bold))
                    .foregroundStyle(Theme.accent)
                Text("TOOLBOX")
                    .font(FT.label(10, weight: .bold))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.top, Spacing.sm)
            .padding(.bottom, Spacing.xs)

            Divider()
                .overlay(Color.white.opacity(0.3))

            // Navigation
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ForEach(groupedSections, id: \.0) { group, sections in
                        VStack(alignment: .leading, spacing: Spacing.xxxs) {
                            Text(group.uppercased())
                                .font(FT.label(9))
                                .foregroundStyle(Theme.textMuted)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.top, Spacing.xxxs)

                            ForEach(sections) { item in
                                sidebarRow(item)
                            }
                        }
                    }
                }
                .padding(.top, Spacing.xxxs)
            }

            Spacer()

            Divider()
                .overlay(Color.white.opacity(0.3))

            // Version
            HStack {
                Text(AppInfo.displayVersion)
                    .font(FT.label(9))
                    .foregroundStyle(Theme.textMuted)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
        }
        .background(Theme.sidebar)
    }

    private func sidebarRow(_ item: ToolSection) -> some View {
        Button {
            selection = item
        } label: {
            HStack(spacing: Spacing.xxs) {
                // Dot indicator
                Circle()
                    .fill(selection == item ? Theme.accent : Color.clear)
                    .frame(width: 6, height: 6)

                Image(systemName: item.systemImage)
                    .font(.system(size: 13))
                    .foregroundStyle(selection == item ? Theme.accent : Theme.textSecondary)
                    .frame(width: 18)

                Text(item.rawValue)
                    .font(FT.data(13, weight: selection == item ? .medium : .regular))
                    .foregroundStyle(selection == item ? Theme.textPrimary : Theme.textSecondary)

                Spacer()
            }
            .padding(.horizontal, Spacing.xs)
            .padding(.vertical, 6)
            .background(selection == item ? Theme.sidebarAccent : Color.clear)
        }
        .buttonStyle(.plain)
    }
}
