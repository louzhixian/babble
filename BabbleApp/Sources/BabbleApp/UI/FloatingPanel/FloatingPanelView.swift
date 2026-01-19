// BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelView.swift

import AppKit
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

                if controller.panelState.status == .recording {
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
            switch controller.panelState.status {
            case .idle:
                Image(systemName: "mic")
                    .foregroundColor(.secondary)
            case .recording:
                Image(systemName: "mic.fill")
                    .foregroundColor(Color(controller.panelState.micColor))
            case .processing:
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
            case .pasteFailed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(controller.panelState.micColor))
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(Color(controller.panelState.micColor))
            }
        }
    }

    private var statusText: String {
        switch controller.panelState.status {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .processing:
            return "Processing..."
        case .pasteFailed:
            return controller.panelState.message ?? "你可以在目标位置粘贴"
        case .error:
            return controller.panelState.message ?? "Something went wrong"
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
