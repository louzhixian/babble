// BabbleApp/Sources/BabbleApp/BabbleApp.swift

import SwiftUI

@main
struct BabbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
