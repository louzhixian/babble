// BabbleApp/Sources/BabbleApp/UI/Setup/SetupCompleteView.swift

import SwiftUI

/// View shown after permissions are granted, guides user through service initialization
struct SetupCompleteView: View {
    enum SetupState {
        case permissionsGranted
        case startingService
        case loadingModel
        case serviceError(String)
        case ready
    }

    @State private var state: SetupState = .permissionsGranted
    var startService: () async throws -> Void
    var warmupModel: () async throws -> Void
    var onComplete: () -> Void

    private var l: LocalizedStrings { L10n.system }

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
        case .loadingModel:
            Image(systemName: "arrow.down.circle.fill")
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
            return l.permissionsGranted
        case .startingService:
            return l.startingSpeechService
        case .loadingModel:
            return l.loadingSpeechModel
        case .serviceError:
            return l.serviceError
        case .ready:
            return l.allSet
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
        case .loadingModel:
            loadingModelContent
        case .serviceError(let message):
            serviceErrorContent(message: message)
        case .ready:
            readyContent
        }
    }

    // MARK: - Permissions Granted Content

    private var permissionsGrantedContent: some View {
        VStack(spacing: 16) {
            Text(l.permissionsReadyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text(l.continueToStart)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(l.continueButton) {
                startSetup()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func startSetup() {
        state = .startingService
        Task {
            do {
                // Step 1: Start the service
                try await startService()
                await MainActor.run {
                    state = .loadingModel
                }

                // Step 2: Warmup (download and load model)
                try await warmupModel()
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

    // MARK: - Starting Service Content

    private var startingServiceContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(l.initializingService)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Loading Model Content

    private var loadingModelContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text(l.downloadingModel)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(l.downloadingModelHint)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Service Error Content

    private func serviceErrorContent(message: String) -> some View {
        VStack(spacing: 16) {
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button(l.retry) {
                startSetup()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Ready Content

    private var readyContent: some View {
        VStack(spacing: 16) {
            Text(l.babbleReady)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                Text(l.waysToStart)
                    .font(.caption)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Image(systemName: "keyboard")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text(l.pressHotkey)
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text(l.forceTouchTrackpad)
                        .font(.caption)
                }

                HStack(spacing: 8) {
                    Image(systemName: "cursorarrow.click")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(l.moveToHotCorner)
                            .font(.caption)
                        Text(l.enableInSettings)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.vertical, 8)

            Button(l.startUsingBabble) {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
