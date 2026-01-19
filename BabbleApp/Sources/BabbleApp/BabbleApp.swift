// BabbleApp/Sources/BabbleApp/BabbleApp.swift

import SwiftUI

@main
struct BabbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainWindowView(
                historyStore: appDelegate.coordinator.historyStore,
                settingsStore: appDelegate.coordinator.settingsStore
            )
        }

        Settings {
            EmptyView()
        }
    }
}
