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
    @Published var refineMode: RefineMode = .punctuate

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
        } catch {
            state = .error("Failed to start recording: \(error.localizedDescription)")
            // Auto-reset to idle after showing error
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                state = .idle
            }
        }
    }

    private func stopAndProcess() {
        guard let audioURL = audioRecorder.stopRecording() else {
            state = .error("No audio recorded")
            // Auto-reset to idle after showing error
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                state = .idle
            }
            return
        }

        Task {
            await processAudio(at: audioURL)
        }
    }

    private func processAudio(at url: URL) async {
        state = .transcribing

        do {
            // Ensure Whisper service is running
            try await processManager.ensureRunning()

            // Transcribe
            let result = try await whisperClient.transcribe(audioURL: url)

            guard !result.text.isEmpty else {
                state = .error("No speech detected")
                // Auto-reset to idle after showing error
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                state = .idle
                return
            }

            // Refine
            state = .refining
            let refinedText = try await refineService.refine(text: result.text, mode: refineMode)

            // Paste
            try PasteService.pasteText(refinedText)

            state = .completed(refinedText)

            // Reset after a short delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            state = .idle

        } catch {
            state = .error(error.localizedDescription)
            // Auto-reset to idle after showing error
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            state = .idle
        }

        // Clean up audio file
        try? FileManager.default.removeItem(at: url)
    }

    func reset() {
        audioRecorder.reset()
        state = .idle
    }
}
