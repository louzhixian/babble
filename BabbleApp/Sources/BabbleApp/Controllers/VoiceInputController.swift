// BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift

import Foundation
import SwiftUI

enum VoiceInputState {
    case idle
    case recording
    case transcribing
    case refining
    case completed(String)
    case error(String)
}

@MainActor
class VoiceInputController: ObservableObject {
    @Published var state: VoiceInputState = .idle
    @Published var audioLevel: Float = 0
    @Published var refineOptions: Set<RefineOption> = [.punctuate]
    @Published var panelState = FloatingPanelState(status: .idle, message: nil)

    private let audioRecorder = AudioRecorder()
    private let whisperClient = WhisperClient()
    private let refineService = RefineService()
    private let hotkeyManager = HotkeyManager()
    private let processManager = WhisperProcessManager()

    private var isToggleRecording = false  // For toggle mode

    init() {
        // Observe audio level from recorder
        audioRecorder.$audioLevel
            .assign(to: &$audioLevel)
    }

    func start() {
        hotkeyManager.register { [weak self] event in
            Task { @MainActor in
                self?.handleHotkeyEvent(event)
            }
        }
    }

    func stop() {
        hotkeyManager.unregister()
        Task {
            await processManager.stop()
        }
    }

    private func handleHotkeyEvent(_ event: HotkeyEvent) {
        switch event {
        case .shortPress:
            // Toggle mode
            if case .recording = state {
                stopAndProcess()
            } else if case .idle = state {
                startRecording()
                isToggleRecording = true
            }

        case .longPressStart:
            // Push-to-talk start
            if case .idle = state {
                startRecording()
                isToggleRecording = false
            }

        case .longPressEnd:
            // Push-to-talk end, or toggle mode stop (if user held key too long)
            if case .recording = state {
                stopAndProcess()
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
            let result = try await whisperClient.transcribe(audioURL: url)

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
            if !refineOptions.isEmpty {
                state = .refining
                do {
                    finalText = try await refineService.refine(text: result.text, options: refineOptions)
                } catch {
                    // Refinement failed (e.g., AFM not available), use raw transcription
                    print("Refinement failed, using raw transcription: \(error.localizedDescription)")
                }
            }

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
            if case .completed = state {
                state = .idle
            }

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
