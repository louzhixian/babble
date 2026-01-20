import AVFoundation
import Foundation

enum AudioValidationResult: Sendable {
    case valid
    case tooShort(TimeInterval)
    case silent
}

struct AudioValidator: Sendable {
    private let minDuration: TimeInterval
    private let silenceThreshold: Float  // dB, values above this are considered silence

    init(minDuration: TimeInterval = 1.0, silenceThreshold: Float = -40.0) {
        self.minDuration = minDuration
        self.silenceThreshold = silenceThreshold
    }

    func validate(audioURL: URL) async -> AudioValidationResult {
        do {
            let asset = AVURLAsset(url: audioURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            // Check duration first
            if durationSeconds < minDuration {
                return .tooShort(durationSeconds)
            }

            // Check for silence using audio file peak analysis
            let isSilent = await checkIfSilent(url: audioURL)
            if isSilent {
                return .silent
            }

            return .valid
        } catch {
            // If we can't analyze, assume it's valid and let transcription handle it
            return .valid
        }
    }

    private func checkIfSilent(url: URL) async -> Bool {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)

            guard frameCount > 0 else { return true }

            let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
            try file.read(into: buffer)

            // Calculate peak amplitude across ALL channels
            // This handles stereo recordings where speech may be on any channel
            guard let channelData = buffer.floatChannelData else { return true }

            var peak: Float = 0
            let channelCount = Int(format.channelCount)
            let frameLength = Int(buffer.frameLength)

            for channel in 0..<channelCount {
                let data = channelData[channel]
                for i in 0..<frameLength {
                    let sample = abs(data[i])
                    if sample > peak {
                        peak = sample
                    }
                }
            }

            // Convert to dB
            let peakDb = peak > 0 ? 20 * log10(peak) : -Float.infinity

            // If peak is below silence threshold, consider it silent
            return peakDb < silenceThreshold
        } catch {
            // If analysis fails, assume not silent
            return false
        }
    }
}
