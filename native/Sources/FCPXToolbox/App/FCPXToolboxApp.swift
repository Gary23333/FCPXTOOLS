import SwiftUI

@main
struct FCPXToolboxApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .frame(minWidth: 1080, minHeight: 680)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1280, height: 800)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
    }
}
