import Combine
import XCTest
@testable import BabbleApp

@MainActor
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

        var cancellables = Set<AnyCancellable>()

        let clearClipboardExpectation = expectation(description: "publishes clearClipboardAfterCopy change")
        store.objectWillChange.first().sink {
            clearClipboardExpectation.fulfill()
        }.store(in: &cancellables)

        store.clearClipboardAfterCopy.toggle()
        wait(for: [clearClipboardExpectation], timeout: 1.0)
    }

    func testPersistsRefineEnabled() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        // Default is true
        XCTAssertTrue(store.refineEnabled)

        store.refineEnabled = false
        XCTAssertFalse(store.refineEnabled)

        // Verify it persists by creating a new store with same defaults
        let store2 = SettingsStore(userDefaults: defaults)
        XCTAssertFalse(store2.refineEnabled)
    }

    func testPersistsRefinePrompt() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        // Default is empty string
        XCTAssertEqual(store.refinePrompt, "")

        store.refinePrompt = "Custom prompt"
        XCTAssertEqual(store.refinePrompt, "Custom prompt")

        // Verify it persists by creating a new store with same defaults
        let store2 = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store2.refinePrompt, "Custom prompt")
    }

    func testEffectiveRefinePromptUsesDefaultWhenEmpty() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        // When refinePrompt is empty, effectiveRefinePrompt should return default
        XCTAssertEqual(store.effectiveRefinePrompt, RefineService.defaultPrompt)

        // When custom prompt is set, effectiveRefinePrompt should return it
        store.refinePrompt = "Custom prompt"
        XCTAssertEqual(store.effectiveRefinePrompt, "Custom prompt")
    }

    func testPersistsForceTouchEnabled() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertFalse(store.forceTouchEnabled)
        store.forceTouchEnabled = true
        XCTAssertTrue(store.forceTouchEnabled)

        // Verify persistence
        let store2 = SettingsStore(userDefaults: defaults)
        XCTAssertTrue(store2.forceTouchEnabled)
    }

    func testDefaultsForceTouchHoldSecondsToTwoSeconds() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        XCTAssertEqual(store.forceTouchHoldSeconds, 2.0, accuracy: 0.001)
    }

    func testPersistsForceTouchHoldSeconds() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        store.forceTouchHoldSeconds = 1.5
        XCTAssertEqual(store.forceTouchHoldSeconds, 1.5, accuracy: 0.001)

        // Verify persistence
        let store2 = SettingsStore(userDefaults: defaults)
        XCTAssertEqual(store2.forceTouchHoldSeconds, 1.5, accuracy: 0.001)
    }
}
