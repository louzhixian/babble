import XCTest
@testable import BabbleApp

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testUpdatesHotzoneEnabled() {
        let defaults = UserDefaults(suiteName: "SettingsViewModelTests")!
        let store = SettingsStore(userDefaults: defaults)
        let model = SettingsViewModel(store: store)
        model.hotzoneEnabled = true
        XCTAssertTrue(store.hotzoneEnabled)
    }

    func testUpdatesForceTouchEnabled() {
        let defaults = UserDefaults(suiteName: "SettingsViewModelTests")!
        defaults.removePersistentDomain(forName: "SettingsViewModelTests")
        let store = SettingsStore(userDefaults: defaults)
        let model = SettingsViewModel(store: store)
        model.forceTouchEnabled = true
        XCTAssertTrue(store.forceTouchEnabled)
    }

    func testUpdatesForceTouchHoldSeconds() {
        let defaults = UserDefaults(suiteName: "SettingsViewModelTests")!
        defaults.removePersistentDomain(forName: "SettingsViewModelTests")
        let store = SettingsStore(userDefaults: defaults)
        let model = SettingsViewModel(store: store)
        model.forceTouchHoldSeconds = 1.5
        XCTAssertEqual(store.forceTouchHoldSeconds, 1.5, accuracy: 0.001)
    }
}
