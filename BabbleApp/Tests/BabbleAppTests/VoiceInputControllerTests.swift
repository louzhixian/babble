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

    func testTargetAppNameRespectsSetting() {
        let defaults = UserDefaults(suiteName: "VoiceInputControllerTests")!
        defaults.removePersistentDomain(forName: "VoiceInputControllerTests")
        let settingsStore = SettingsStore(userDefaults: defaults)
        settingsStore.recordTargetApp = false

        let controller = VoiceInputController(
            historyStore: HistoryStore(limit: 10),
            settingsStore: settingsStore,
            frontmostAppNameProvider: { "Arc" }
        )

        XCTAssertNil(controller.targetAppNameForHistory())

        settingsStore.recordTargetApp = true
        XCTAssertEqual(controller.targetAppNameForHistory(), "Arc")
    }
}
