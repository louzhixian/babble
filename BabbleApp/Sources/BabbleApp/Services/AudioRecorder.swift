// BabbleApp/Sources/BabbleApp/Services/AudioRecorder.swift

import AVFoundation
import Foundation

enum RecordingState {
    case idle
    case recording
    case processing
}

enum AudioRecorderError: Error, LocalizedError {
    case recordingFailed

    var errorDescription: String? {
        switch self {
        case .recordingFailed:
            return "Failed to start recording. Please check microphone permission."
        }
    }
}

@MainActor
class AudioRecorder: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var recordingURL: URL?

    var isRecording: Bool {
        state == .recording
    }

    func startRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true

        guard audioRecorder?.record() == true else {
            audioRecorder = nil
            throw AudioRecorderError.recordingFailed
        }

        recordingURL = url
        state = .recording

        // Start level monitoring
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }

    func stopRecording() -> URL? {
        levelTimer?.invalidate()
        levelTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        state = .processing

        let url = recordingURL
        recordingURL = nil
        return url
    }

    func reset() {
        state = .idle
        audioLevel = 0
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        // Convert dB to 0-1 range
        audioLevel = max(0, min(1, (level + 60) / 60))
    }
}
