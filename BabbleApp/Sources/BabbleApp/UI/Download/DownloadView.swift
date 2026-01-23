// BabbleApp/Sources/BabbleApp/UI/Download/DownloadView.swift

import AppKit
import SwiftUI

/// View displayed during first-launch download of whisper-service
struct DownloadView: View {
    @ObservedObject var downloadManager: DownloadManager
    var onComplete: () -> Void

    private let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter
    }()

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            stateIcon
                .font(.system(size: 48))
                .frame(height: 60)

            // Title
            Text("Setting Up Babble")
                .font(.title)
                .fontWeight(.semibold)

            // Content based on state
            stateContent
        }
        .padding(32)
        .frame(width: 400, height: 300)
        .onChange(of: downloadManager.state) { _, newState in
            if case .completed = newState {
                onComplete()
            }
        }
    }

    // MARK: - State Icon

    @ViewBuilder
    private var stateIcon: some View {
        switch downloadManager.state {
        case .idle, .checking, .downloading, .verifying:
            Image(systemName: "arrow.down.circle")
                .foregroundStyle(.blue)

        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

        case .downloadComplete, .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }

    // MARK: - State Content

    @ViewBuilder
    private var stateContent: some View {
        switch downloadManager.state {
        case .idle, .checking:
            checkingContent

        case .downloading(let progress, let downloadedBytes, let totalBytes):
            downloadingContent(progress: progress, downloadedBytes: downloadedBytes, totalBytes: totalBytes)

        case .verifying:
            verifyingContent

        case .failed(let error, let retryCount):
            failedContent(error: error, retryCount: retryCount)

        case .downloadComplete:
            downloadCompleteContent

        case .completed:
            completedContent
        }
    }

    // MARK: - Checking Content

    private var checkingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Checking for updates...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Downloading Content

    private func downloadingContent(progress: Double, downloadedBytes: Int64, totalBytes: Int64) -> some View {
        VStack(spacing: 12) {
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(width: 280)

            Text("Downloading speech engine...")
                .foregroundStyle(.secondary)

            Text(formatDownloadProgress(downloadedBytes: downloadedBytes, totalBytes: totalBytes))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func formatDownloadProgress(downloadedBytes: Int64, totalBytes: Int64) -> String {
        let downloadedStr = byteFormatter.string(fromByteCount: downloadedBytes)
        if totalBytes > 0 {
            let totalStr = byteFormatter.string(fromByteCount: totalBytes)
            return "\(downloadedStr) / \(totalStr)"
        } else {
            return downloadedStr
        }
    }

    // MARK: - Verifying Content

    private var verifyingContent: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Verifying download...")
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Failed Content

    private func failedContent(error: DownloadError, retryCount: Int) -> some View {
        VStack(spacing: 16) {
            Text("Download Failed")
                .font(.headline)
                .foregroundStyle(.primary)

            Text(error.localizedDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            HStack(spacing: 16) {
                if retryCount < downloadManager.maxRetries {
                    Button("Retry") {
                        Task {
                            await downloadManager.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Manual Download") {
                    NSWorkspace.shared.open(downloadManager.manualDownloadURL)
                }
                .buttonStyle(.bordered)

                Button("Check Again") {
                    Task {
                        await downloadManager.downloadIfNeeded()
                    }
                }
                .buttonStyle(.bordered)
            }

            Text("Download both whisper-service and whisper-service.sha256,\nthen place them in ~/Library/Application Support/Babble/\nClick \"Check Again\" after placing the files.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: - Download Complete Content (waiting for user confirmation)

    private var downloadCompleteContent: some View {
        VStack(spacing: 16) {
            Text("Download Complete!")
                .font(.headline)
                .foregroundStyle(.green)

            Text("Next, Babble needs permissions to work properly:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "mic.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Microphone — for voice recording")
                        .font(.caption)
                }
                HStack(spacing: 8) {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 20)
                    Text("Accessibility — for pasting text")
                        .font(.caption)
                }
            }
            .padding(.vertical, 8)

            Button("Continue") {
                downloadManager.confirmDownloadComplete()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Completed Content

    private var completedContent: some View {
        Text("Ready!")
            .font(.headline)
            .foregroundStyle(.green)
    }
}
