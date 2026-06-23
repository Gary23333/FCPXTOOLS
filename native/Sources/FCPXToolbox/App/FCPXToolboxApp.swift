import SwiftUI

@main
struct FCPXToolboxApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1080, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}

            // 视图切换快捷键
            CommandGroup(replacing: .toolbar) {
                ForEach(Array(ToolSection.allCases.enumerated()), id: \.element.id) { index, section in
                    if index < 9 {
                        Button(section.rawValue) {
                            appState.selectedSection = section
                        }
                        .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                    }
                }
            }
        }
    }
}

/// 全局应用状态，用于跨视图共享当前选中的工具分区。
final class AppState: ObservableObject {
    @Published var selectedSection: ToolSection = .cleanup
}
