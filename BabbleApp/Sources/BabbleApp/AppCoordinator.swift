import Foundation

@MainActor
final class AppCoordinator: ObservableObject {
    let historyStore: HistoryStore
    let settingsStore: SettingsStore
    let mainWindowRouter: MainWindowRouter
    let voiceInputController: VoiceInputController
    let downloadManager: DownloadManager
    private nonisolated(unsafe) var historyLimitObserver: NSObjectProtocol?

    init(settingsStore: SettingsStore = SettingsStore()) {
        self.settingsStore = settingsStore
        self.historyStore = HistoryStore(limit: settingsStore.historyLimit)
        self.mainWindowRouter = MainWindowRouter()
        self.downloadManager = DownloadManager()
        self.voiceInputController = VoiceInputController(
            historyStore: historyStore,
            settingsStore: settingsStore
        )

        historyLimitObserver = NotificationCenter.default.addObserver(
            forName: .settingsHistoryLimitDidChange,
            object: settingsStore,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.historyStore.updateLimit(self.settingsStore.historyLimit)
            }
        }
    }

    deinit {
        if let observer = historyLimitObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}
