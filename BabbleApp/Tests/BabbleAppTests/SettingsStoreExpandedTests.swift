import Combine
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

    func testPublishesCopySettingsChanges() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        let playSoundExpectation = expectation(description: "publishes playSoundOnCopy change")
        var cancellables = Set<AnyCancellable>()
        store.objectWillChange.first().sink {
            playSoundExpectation.fulfill()
        }.store(in: &cancellables)

        store.playSoundOnCopy.toggle()
        wait(for: [playSoundExpectation], timeout: 1.0)

        let clearClipboardExpectation = expectation(description: "publishes clearClipboardAfterCopy change")
        store.objectWillChange.first().sink {
            clearClipboardExpectation.fulfill()
        }.store(in: &cancellables)

        store.clearClipboardAfterCopy.toggle()
        wait(for: [clearClipboardExpectation], timeout: 1.0)
    }
}
