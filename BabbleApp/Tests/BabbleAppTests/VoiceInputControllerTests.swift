import XCTest
@testable import BabbleApp

@MainActor
final class VoiceInputControllerTests: XCTestCase {
    func testWhisperRequestConfigUsesSettings() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.whisperPort = 9000
        settingsStore.defaultLanguage = "en"

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { "Arc" }
        )

        let config = controller.whisperRequestConfig()
        XCTAssertEqual(config.port, 9000)
        XCTAssertEqual(config.language, "en")
    }

    func testWhisperRequestConfigOmitsEmptyLanguage() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.defaultLanguage = "  "

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )

        let config = controller.whisperRequestConfig()
        XCTAssertNil(config.language)
    }

    func testHotzoneLongPressEndDoesNotStopToggleRecording() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )
        controller.state = .recording
        controller.setToggleRecordingForTesting(true)

        controller.handleHotkeyEventForTesting(.longPressEnd(.hotzone))

        if case .recording = controller.state {
            return
        }
        XCTFail("Expected toggle recording to remain active after longPressEnd.")
    }

    func testHotzoneLongPressEndStopsHotzoneRecording() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )
        controller.state = .recording
        controller.setToggleRecordingForTesting(false)
        controller.setActiveLongPressSourceForTesting(.hotzone)

        controller.handleHotkeyEventForTesting(.longPressEnd(.hotzone))

        if case .recording = controller.state {
            XCTFail("Expected non-toggle recording to stop after longPressEnd.")
        }
    }

    func testKeyboardLongPressEndStopsToggleRecording() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )
        controller.state = .recording
        controller.setToggleRecordingForTesting(true)

        controller.handleHotkeyEventForTesting(.longPressEnd(.keyboard))

        if case .recording = controller.state {
            XCTFail("Expected toggle recording to stop after keyboard longPressEnd.")
        }
    }

    func testHotzoneLongPressEndDoesNotStopKeyboardRecording() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )
        controller.state = .recording
        controller.setToggleRecordingForTesting(false)
        controller.setActiveLongPressSourceForTesting(.keyboard)

        controller.handleHotkeyEventForTesting(.longPressEnd(.hotzone))

        if case .recording = controller.state {
            return
        }
        XCTFail("Expected keyboard recording to remain active after hotzone longPressEnd.")
    }

    func testCancelRecordingResetsStateToIdle() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )
        controller.state = .recording
        controller.setToggleRecordingForTesting(true)

        controller.handleHotkeyEventForTesting(.cancelRecording)

        if case .idle = controller.state {
            return
        }
        XCTFail("Expected state to reset to idle after cancelRecording")
    }

    func testCancelRecordingDoesNothingWhenNotRecording() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )
        controller.state = .idle

        controller.handleHotkeyEventForTesting(.cancelRecording)

        if case .idle = controller.state {
            return
        }
        XCTFail("Expected state to remain idle after cancelRecording when not recording")
    }

    func testForceTouchLongPressEndStopsForceTouchRecording() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )
        controller.state = .recording
        controller.setToggleRecordingForTesting(false)
        controller.setActiveLongPressSourceForTesting(.forceTouch)

        controller.handleHotkeyEventForTesting(.longPressEnd(.forceTouch))

        if case .recording = controller.state {
            XCTFail("Expected force touch recording to stop after longPressEnd.")
        }
    }

    func testForceTouchLongPressEndDoesNotStopKeyboardRecording() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { nil }
        )
        controller.state = .recording
        controller.setToggleRecordingForTesting(false)
        controller.setActiveLongPressSourceForTesting(.keyboard)

        controller.handleHotkeyEventForTesting(.longPressEnd(.forceTouch))

        if case .recording = controller.state {
            return
        }
        XCTFail("Expected keyboard recording to remain active after forceTouch longPressEnd.")
    }
}
