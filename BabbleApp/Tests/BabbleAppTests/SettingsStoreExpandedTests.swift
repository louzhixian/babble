import XCTest
@testable import BabbleApp

final class SettingsStoreExpandedTests: XCTestCase {
    func testPersistsHistoryLimit() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        store.historyLimit = 200
        XCTAssertEqual(store.historyLimit, 200)
    }

    func testDefaultsHotzoneHoldSecondsToTwoSeconds() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.hotzoneHoldSeconds, 2.0, accuracy: 0.001)
    }
}
