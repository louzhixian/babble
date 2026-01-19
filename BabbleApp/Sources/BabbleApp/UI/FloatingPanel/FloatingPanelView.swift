// BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelView.swift

import SwiftUI

struct FloatingPanelView: View {
    @ObservedObject var controller: VoiceInputController

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .font(.title2)

            // Status text and audio level
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.headline)

                if case .recording = controller.state {
                    AudioLevelView(level: controller.audioLevel)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }

    private var statusIcon: some View {
        Group {
            switch controller.state {
            case .idle:
                Image(systemName: "mic")
                    .foregroundColor(.secondary)
            case .recording:
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            case .transcribing:
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
            case .refining:
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
    }

    private var statusText: String {
        switch controller.state {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .refining:
            return "Refining..."
        case .completed(let text):
            return String(text.prefix(30)) + (text.count > 30 ? "..." : "")
        case .error(let message):
            return message
        }
    }
}

struct AudioLevelView: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
    }
}
