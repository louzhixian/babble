import Foundation

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var historyLimit: Int {
        didSet { store.historyLimit = historyLimit }
    }

    @Published var refineEnabled: Bool {
        didSet { store.refineEnabled = refineEnabled }
    }

    // Refine prompt uses explicit save, not auto-save
    @Published var refinePromptDraft: String
    @Published var refinePromptHasChanges: Bool = false

    @Published var defaultLanguage: String {
        didSet { store.defaultLanguage = defaultLanguage }
    }

    @Published var whisperPort: Int {
        didSet { store.whisperPort = whisperPort }
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

    @Published var trackpadHotzoneEnabled: Bool {
        didSet { store.trackpadHotzoneEnabled = trackpadHotzoneEnabled }
    }

    @Published var trackpadHotzoneCorner: HotzoneCorner {
        didSet { store.trackpadHotzoneCorner = trackpadHotzoneCorner }
    }

    private let store: SettingsStore

    init(store: SettingsStore) {
        self.store = store
        historyLimit = store.historyLimit
        refineEnabled = store.refineEnabled
        refinePromptDraft = store.refinePrompt
        defaultLanguage = store.defaultLanguage
        whisperPort = store.whisperPort
        clearClipboardAfterCopy = store.clearClipboardAfterCopy
        hotzoneEnabled = store.hotzoneEnabled
        hotzoneCorner = store.hotzoneCorner
        hotzoneHoldSeconds = store.hotzoneHoldSeconds
        forceTouchEnabled = store.forceTouchEnabled
        forceTouchHoldSeconds = store.forceTouchHoldSeconds
        trackpadHotzoneEnabled = store.trackpadHotzoneEnabled
        trackpadHotzoneCorner = store.trackpadHotzoneCorner
    }

    func updateRefinePromptDraft(_ newValue: String) {
        refinePromptDraft = newValue
        refinePromptHasChanges = newValue != store.refinePrompt
    }

    func saveRefinePrompt() {
        store.refinePrompt = refinePromptDraft
        refinePromptHasChanges = false
    }

    func discardRefinePromptChanges() {
        refinePromptDraft = store.refinePrompt
        refinePromptHasChanges = false
    }
}
