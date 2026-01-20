// BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift

import Foundation
import AppKit

enum VoiceInputState: Sendable {
    case idle
    case recording
    case transcribing
    case refining
    case completed(String)
    case error(String)
}

@MainActor
class VoiceInputController: NSObject, ObservableObject {
    @Published var state: VoiceInputState = .idle
    @Published var audioLevel: Float = 0
    @Published var recordingDuration: TimeInterval = 0
    @Published var panelState = FloatingPanelState(status: .idle, message: nil)

    private let audioRecorder = AudioRecorder()
    private let frontmostAppNameProvider: () -> String?
    private let refineService = RefineService()
    private let hotkeyManager = HotkeyManager()
    private let processManager: WhisperProcessManager
    private let panelStateReducer = PanelStateReducer()
    private let historyStore: HistoryStore
    private let settingsStore: SettingsStore

    private var isToggleRecording = false  // For toggle mode
    private var activeLongPressSource: HotkeySource?

    init(
        historyStore: HistoryStore = HistoryStore(limit: 100),
        settingsStore: SettingsStore = SettingsStore(),
        frontmostAppNameProvider: @escaping () -> String? = { NSWorkspace.shared.frontmostApplication?.localizedName }
    ) {
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        self.frontmostAppNameProvider = frontmostAppNameProvider
        self.processManager = WhisperProcessManager(port: settingsStore.whisperPort)
        super.init()
        // Observe audio level and duration from recorder
        audioRecorder.$audioLevel
            .assign(to: &$audioLevel)
        audioRecorder.$recordingDuration
            .assign(to: &$recordingDuration)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleHotzoneChange(_:)),
            name: .settingsHotzoneDidChange,
            object: settingsStore
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWhisperPortChange(_:)),
            name: .settingsWhisperPortDidChange,
            object: settingsStore
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleForceTouchChange(_:)),
            name: .settingsForceTouchDidChange,
            object: settingsStore
        )
    }

    func start() {
        hotkeyManager.register { [weak self] event in
            Task { @MainActor in
                self?.handleHotkeyEvent(event)
            }
        }
        applyHotzoneSettings()
        applyForceTouchSettings()
    }

    func stop() {
        hotkeyManager.unregister()
        Task {
            await processManager.stop()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    private func applyHotzoneSettings() {
        hotkeyManager.configureHotzone(
            enabled: settingsStore.hotzoneEnabled,
            corner: settingsStore.hotzoneCorner,
            holdSeconds: settingsStore.hotzoneHoldSeconds
        )
    }

    private func applyForceTouchSettings() {
        hotkeyManager.configureForceTouch(
            enabled: settingsStore.forceTouchEnabled,
            holdSeconds: settingsStore.forceTouchHoldSeconds
        )
    }

    @objc private func handleHotzoneChange(_ notification: Notification) {
        applyHotzoneSettings()
    }

    @objc private func handleForceTouchChange(_ notification: Notification) {
        applyForceTouchSettings()
    }

    @objc private func handleWhisperPortChange(_ notification: Notification) {
        let port = settingsStore.whisperPort
        Task {
            await processManager.updatePort(port)
        }
    }

    func whisperRequestConfig() -> (port: Int, language: String?) {
        let trimmedLanguage = settingsStore.defaultLanguage.trimmingCharacters(in: .whitespacesAndNewlines)
        let language = trimmedLanguage.isEmpty ? nil : trimmedLanguage
        return (port: settingsStore.whisperPort, language: language)
    }

    func targetAppNameForHistory() -> String? {
        return frontmostAppNameProvider()
    }

#if DEBUG
    func handleHotkeyEventForTesting(_ event: HotkeyEvent) {
        handleHotkeyEvent(event)
    }

    func setToggleRecordingForTesting(_ value: Bool) {
        isToggleRecording = value
    }

    func setActiveLongPressSourceForTesting(_ value: HotkeySource?) {
        activeLongPressSource = value
    }
#endif

    private func handleHotkeyEvent(_ event: HotkeyEvent) {
        switch event {
        case .shortPress:
            // Toggle mode
            if case .recording = state {
                stopAndProcess()
            } else if case .idle = state {
                startRecording()
                isToggleRecording = true
                activeLongPressSource = nil
            }

        case .longPressStart(let source):
            // Push-to-talk start
            if case .idle = state {
                startRecording()
                isToggleRecording = false
                activeLongPressSource = source
            }

        case .longPressEnd(let source):
            // Push-to-talk end, or toggle mode stop (if user held key too long)
            if case .recording = state {
                if isToggleRecording {
                    if source == .keyboard {
                        stopAndProcess()
                    }
                } else if activeLongPressSource == source {
                    stopAndProcess()
                }
            }

        case .cancelRecording:
            // ESC key pressed - cancel current recording
            if case .recording = state {
                audioRecorder.discardRecording()
                state = .idle
                panelState = FloatingPanelState(status: .idle, message: nil)
                isToggleRecording = false
                activeLongPressSource = nil
            }
        }
    }

    private func startRecording() {
        do {
            try audioRecorder.startRecording()
            state = .recording
            panelState = FloatingPanelState(status: .recording, message: nil)
        } catch {
            state = .error("Failed to start recording: \(error.localizedDescription)")
            panelState = FloatingPanelState(
                status: .error,
                message: "Failed to start recording: \(error.localizedDescription)"
            )
            // Auto-reset to idle after showing error, but only if still in error state
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if case .error = state {
                    state = .idle
                    panelState = FloatingPanelState(status: .idle, message: nil)
                }
            }
        }
    }

    private func stopAndProcess() {
        guard let audioURL = audioRecorder.stopRecording() else {
            activeLongPressSource = nil
            state = .error("No audio recorded")
            panelState = FloatingPanelState(status: .error, message: "No audio recorded")
            // Auto-reset to idle after showing error, but only if still in error state
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if case .error = state {
                    state = .idle
                    panelState = FloatingPanelState(status: .idle, message: nil)
                }
            }
            return
        }

        activeLongPressSource = nil
        Task {
            await processAudio(at: audioURL)
        }
    }

    private func processAudio(at url: URL) async {
        state = .transcribing
        panelState = FloatingPanelState(status: .processing, message: nil)

        do {
            // Ensure Whisper service is running
            try await processManager.ensureRunning()

            // Transcribe
            let config = whisperRequestConfig()
            let result = try await WhisperClient(port: config.port).transcribe(
                audioURL: url,
                language: config.language
            )

            guard !result.text.isEmpty else {
                state = .error("No speech detected")
                panelState = FloatingPanelState(status: .error, message: "No speech detected")
                // Auto-reset to idle after showing error, but only if still in error state
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                if case .error = state {
                    state = .idle
                    panelState = FloatingPanelState(status: .idle, message: nil)
                }
                return
            }

            // Refine (with fallback to raw transcription if refinement fails)
            var finalText = result.text
            let options = Set(settingsStore.defaultRefineOptions)
            if !options.isEmpty {
                state = .refining
                do {
                    finalText = try await refineService.refine(
                        text: result.text,
                        options: options,
                        customPrompts: settingsStore.customPrompts
                    )
                } catch {
                    // Refinement failed (e.g., AFM not available), use raw transcription
                    print("Refinement failed, using raw transcription: \(error.localizedDescription)")
                }
            }

            let record = HistoryRecord(
                id: UUID().uuidString,
                timestamp: Date(),
                rawText: result.text,
                refinedText: finalText,
                refineOptions: Array(options),
                targetAppName: targetAppNameForHistory(),
                editedText: nil,
                editedVariant: nil
            )
            historyStore.append(record)

            // Paste
            let pasteSucceeded = PasteService().pasteText(finalText)

            state = .completed(finalText)
            if pasteSucceeded {
                panelState = FloatingPanelState(status: .idle, message: nil)
            } else {
                panelState = FloatingPanelState(
                    status: .pasteFailed,
                    message: "你可以在目标位置粘贴"
                )
            }

            // Reset after a short delay, but only if still in completed state
            // (user may have started a new recording during this window)
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            let shouldApplyReset: Bool
            if case .completed = state {
                state = .idle
                shouldApplyReset = true
            } else {
                shouldApplyReset = false
            }
            panelState = panelStateReducer.finalPanelStateAfterDelay(
                pasteSucceeded: pasteSucceeded,
                current: panelState,
                shouldApply: shouldApplyReset
            )

        } catch {
            state = .error(error.localizedDescription)
            panelState = FloatingPanelState(status: .error, message: error.localizedDescription)
            // Auto-reset to idle after showing error, but only if still in error state
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if case .error = state {
                state = .idle
                panelState = FloatingPanelState(status: .idle, message: nil)
            }
        }

        // Clean up audio file
        try? FileManager.default.removeItem(at: url)
    }

    func reset() {
        audioRecorder.reset()
        state = .idle
    }
}
