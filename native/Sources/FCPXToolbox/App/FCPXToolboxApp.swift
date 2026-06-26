import SwiftUI

@main
struct FCPXToolboxApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    init() {
        // 尽早注册 Geist Mono 字体，避免首帧使用回退字体造成闪烁。
        FontLoader.registerFonts()
    }

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

            // 关于菜单项自定义
            CommandGroup(replacing: .appInfo) {
                Button("关于 FCPX 工具箱...") {
                    openWindow(id: "about")
                }
            }

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
        
        // 偏好设置场景 (⌘,)
        Settings {
            SettingsView()
        }
        
        // 关于面板独立窗口
        Window("关于 FCPX 工具箱", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
    }
}

/// 全局应用状态，用于跨视图共享当前选中的工具分区。
@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: ToolSection = .cleanup
    @Published var globalProjectDir: URL? = nil
    
    init() {
        // 启动时读取默认板块设置
        AppPreferences.shared.load()
        if let defaultSection = ToolSection(rawValue: AppPreferences.shared.startupSection) {
            self.selectedSection = defaultSection
        }
        if let defaultScanPath = AppPreferences.shared.defaultScanPath, !defaultScanPath.isEmpty {
            self.globalProjectDir = URL(fileURLWithPath: defaultScanPath)
        }
    }
}
