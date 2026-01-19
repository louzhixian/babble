import Foundation

@MainActor
final class AppCoordinator: NSObject, ObservableObject {
    let historyStore: HistoryStore
    let settingsStore: SettingsStore
    let voiceInputController: VoiceInputController

    init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        self.historyStore = HistoryStore(limit: settingsStore.historyLimit)
        self.voiceInputController = VoiceInputController(
            historyStore: historyStore,
            settingsStore: settingsStore
        )
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHistoryLimitChange(_:)),
            name: .settingsHistoryLimitDidChange,
            object: settingsStore
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func handleHistoryLimitChange(_ notification: Notification) {
        historyStore.updateLimit(settingsStore.historyLimit)
    }
}
