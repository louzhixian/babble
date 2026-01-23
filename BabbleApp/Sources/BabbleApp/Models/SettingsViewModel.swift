import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var historyLimit: Int {
        didSet { store.historyLimit = historyLimit }
    }

    @Published var refineEnabled: Bool {
        didSet { store.refineEnabled = refineEnabled }
    }

    @Published var refinePrompt: String {
        didSet { store.refinePrompt = refinePrompt }
    }

    @Published var defaultLanguage: String {
        didSet { store.defaultLanguage = defaultLanguage }
    }

    @Published var clearClipboardAfterCopy: Bool {
        didSet { store.clearClipboardAfterCopy = clearClipboardAfterCopy }
    }

    @Published var hotzoneEnabled: Bool {
        didSet { store.hotzoneEnabled = hotzoneEnabled }
    }

    @Published var hotzoneCorner: HotzoneCorner {
        didSet { store.hotzoneCorner = hotzoneCorner }
    }

    @Published var hotzoneHoldSeconds: Double {
        didSet { store.hotzoneHoldSeconds = hotzoneHoldSeconds }
    }

    @Published var forceTouchEnabled: Bool {
        didSet { store.forceTouchEnabled = forceTouchEnabled }
    }

    @Published var forceTouchHoldSeconds: Double {
        didSet { store.forceTouchHoldSeconds = forceTouchHoldSeconds }
    }

    @Published var hotkeyConfig: HotkeyConfig {
        didSet { store.hotkeyConfig = hotkeyConfig }
    }

    @Published var appLanguage: AppLanguage {
        didSet { store.appLanguage = appLanguage }
    }

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        historyLimit = store.historyLimit
        refineEnabled = store.refineEnabled
        refinePrompt = store.refinePrompt
        defaultLanguage = store.defaultLanguage
        clearClipboardAfterCopy = store.clearClipboardAfterCopy
        hotzoneEnabled = store.hotzoneEnabled
        hotzoneCorner = store.hotzoneCorner
        hotzoneHoldSeconds = store.hotzoneHoldSeconds
        forceTouchEnabled = store.forceTouchEnabled
        forceTouchHoldSeconds = store.forceTouchHoldSeconds
        hotkeyConfig = store.hotkeyConfig
        appLanguage = store.appLanguage
    }

    func resetRefinePrompt() {
        refinePrompt = RefineService.defaultPrompt
    }
}
