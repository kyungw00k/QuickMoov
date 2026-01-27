import SwiftUI

@main
struct QuickMoovApp: App {
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("showInDock") private var showInDock = true
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            SettingsView()
        }

        MenuBarExtra("QuickMoov", systemImage: "arrow.up.doc", isInserted: $showInMenuBar) {
            Button(String(localized: "menubar_open_window")) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.title == "QuickMoov" || $0.contentView is NSHostingView<ContentView> }) {
                    window.makeKeyAndOrderFront(nil)
                } else {
                    // If no window exists, create one
                    for window in NSApplication.shared.windows {
                        if window.contentView != nil && !(window.title.contains("Settings")) {
                            window.makeKeyAndOrderFront(nil)
                            break
                        }
                    }
                }
            }
            .keyboardShortcut("o", modifiers: .command)

            Divider()

            Button(String(localized: "menubar_quit")) {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}
