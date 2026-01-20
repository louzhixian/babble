// BabbleApp/Sources/BabbleApp/BabbleApp.swift

import SwiftUI

@main
struct BabbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Main window is managed manually by AppDelegate for LSUIElement compatibility
        Settings {
            SettingsView(store: appDelegate.coordinator.settingsStore)
        }
    }
}
