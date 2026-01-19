import XCTest
@testable import BabbleApp

@MainActor
final class AppWiringTests: XCTestCase {
    func testMainWindowUsesSharedStores() {
        let coordinator = AppCoordinator()
        XCTAssertNotNil(coordinator.historyStore)
    }

    func testHistoryLimitUpdatesFromSettings() {
        let defaults = UserDefaults(suiteName: "AppWiringTests")!
        defaults.removePersistentDomain(forName: "AppWiringTests")
        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.historyLimit = 5

        let coordinator = AppCoordinator(settingsStore: settingsStore)
        XCTAssertEqual(coordinator.historyStore.limit, 5)

        settingsStore.historyLimit = 3
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertEqual(coordinator.historyStore.limit, 3)
    }
}
