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
}
