// BabbleApp/Sources/BabbleApp/UI/Setup/SetupCompleteView.swift

import SwiftUI

/// View shown after permissions are granted, guides user through model loading
struct SetupCompleteView: View {
    enum SetupState {
        case permissionsGranted
        case loadingModel
        case ready
    }

    @State private var state: SetupState = .permissionsGranted
    var onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            stateIcon
                .font(.system(size: 48))
                .frame(height: 60)

            // Title
            Text(stateTitle)
                .font(.title)
                .fontWeight(.semibold)

            // Content
            stateContent
        }
        .padding(32)
        .frame(width: 420, height: 320)
    }

    // MARK: - State Icon

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .permissionsGranted:
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.green)
        case .loadingModel:
            Image(systemName: "cpu.fill")
                .foregroundStyle(.blue)
        case .ready:
            Image(systemName: "hand.thumbsup.fill")
                .foregroundStyle(.green)
        }
    }

    // MARK: - State Title

    private var stateTitle: String {
        switch state {
        case .permissionsGranted:
            return "Permissions Granted!"
        case .loadingModel:
            return "Loading Speech Model..."
        case .ready:
            return "All Set!"
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        switch state {
        case .permissionsGranted:
            permissionsGrantedContent
        case .loadingModel:
            loadingModelContent
        case .ready:
            readyContent
        }
    }

    // MARK: - Permissions Granted Content

    private var permissionsGrantedContent: some View {
        VStack(spacing: 16) {
            Text("Microphone and Accessibility permissions are ready.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Next, we'll load the speech recognition model.\nThis may take a moment on first launch.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Load Model") {
                state = .loadingModel
                // Simulate model loading (in real app, this would load the actual model)
                Task {
                    // Give time to show loading state
                    try? await Task.sleep(for: .milliseconds(500))
                    await MainActor.run {
                        state = .ready
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Loading Model Content

    private var loadingModelContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Initializing speech recognition...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ready Content

    private var readyContent: some View {
        VStack(spacing: 16) {
            Text("Babble is ready to use!")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text("Ways to start voice input:")
                    .font(.caption)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Press Option + Space")
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Force Touch the trackpad")
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Move cursor to hot corner")
                        .font(.caption)
                }
            }
            .padding(.vertical, 8)

            Button("Start Using Babble") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
