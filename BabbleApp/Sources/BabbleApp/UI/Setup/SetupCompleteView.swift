// BabbleApp/Sources/BabbleApp/UI/Setup/SetupCompleteView.swift

import SwiftUI

/// View shown after permissions are granted, guides user through service initialization
struct SetupCompleteView: View {
    enum SetupState {
        case permissionsGranted
        case startingService
        case serviceError(String)
        case ready
    }

    @State private var state: SetupState = .permissionsGranted
    var startService: () async throws -> Void
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
        .frame(width: 420, height: 340)
    }

    // MARK: - State Icon

    @ViewBuilder
    private var stateIcon: some View {
        switch state {
        case .permissionsGranted:
            Image(systemName: "checkmark.shield.fill")
                .foregroundStyle(.green)
        case .startingService:
            Image(systemName: "cpu.fill")
                .foregroundStyle(.blue)
        case .serviceError:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
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
        case .startingService:
            return "Starting Speech Service..."
        case .serviceError:
            return "Service Error"
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
        case .startingService:
            startingServiceContent
        case .serviceError(let message):
            serviceErrorContent(message: message)
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

            Text("Click Continue to start the speech recognition service.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Continue") {
                state = .startingService
                Task {
                    do {
                        try await startService()
                        await MainActor.run {
                            state = .ready
                        }
                    } catch {
                        await MainActor.run {
                            state = .serviceError(error.localizedDescription)
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Starting Service Content

    private var startingServiceContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Initializing speech recognition service...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Service Error Content

    private func serviceErrorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                state = .startingService
                Task {
                    do {
                        try await startService()
                        await MainActor.run {
                            state = .ready
                        }
                    } catch {
                        await MainActor.run {
                            state = .serviceError(error.localizedDescription)
                        }
                    }
                }
            }
            .buttonStyle(.borderedProminent)
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

            Text("The speech model (~1.5GB) will download automatically on first use.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Start Using Babble") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
