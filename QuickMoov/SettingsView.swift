import SwiftUI

struct SettingsView: View {
    @AppStorage("showInMenuBar") private var showInMenuBar = false
    @AppStorage("showInDock") private var showInDock = true

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $showInMenuBar) {
                    Label(String(localized: "settings_show_menubar"), systemImage: "menubar.arrow.up.rectangle")
                }
                .onChange(of: showInMenuBar) { newValue in
                    // When hiding from menu bar, Dock must be shown
                    if !newValue && !showInDock {
                        showInDock = true
                    }
                }

                Toggle(isOn: $showInDock) {
                    Label(String(localized: "settings_show_dock"), systemImage: "dock.rectangle")
                }
                .onChange(of: showInDock) { newValue in
                    updateDockVisibility(show: newValue)
                    // When hiding from Dock, menu bar must be shown
                    if !newValue && !showInMenuBar {
                        showInMenuBar = true
                    }
                }
            } header: {
                Text(String(localized: "settings_appearance"))
            } footer: {
                Text(String(localized: "settings_appearance_footer"))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 350, height: 180)
        .onAppear {
            updateDockVisibility(show: showInDock)
        }
    }

    private func updateDockVisibility(show: Bool) {
        if show {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

#Preview {
    SettingsView()
}
