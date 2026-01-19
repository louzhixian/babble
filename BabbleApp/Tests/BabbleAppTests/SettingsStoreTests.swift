import XCTest
@testable import BabbleApp

final class SettingsStoreTests: XCTestCase {
    func testPersistsFloatingPanelPosition() {
        let defaults = UserDefaults(suiteName: "SettingsStoreTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreTests")
        let store = SettingsStore(userDefaults: defaults)

        store.floatingPanelPosition = .left

        XCTAssertEqual(store.floatingPanelPosition, .left)
    }
}
