// BabbleApp/Sources/BabbleApp/Services/DownloadManager.swift

import Combine
import CryptoKit
import Foundation

/// State of the download process
enum DownloadState: Equatable {
    case idle
    case checking
    case downloading(progress: Double, downloadedBytes: Int64, totalBytes: Int64)
    case verifying
    case failed(error: DownloadError, retryCount: Int)
    case completed

    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.checking, .checking),
             (.verifying, .verifying),
             (.completed, .completed):
            return true
        case let (.downloading(lp, ld, lt), .downloading(rp, rd, rt)):
            return lp == rp && ld == rd && lt == rt
        case let (.failed(le, lc), .failed(re, rc)):
            return le == re && lc == rc
        default:
            return false
        }
    }
}

/// Errors that can occur during download
enum DownloadError: Error, Equatable, LocalizedError {
    case networkError(String)
    case checksumMismatch(expected: String, actual: String)
    case fileSystemError(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network error: \(message)"
        case .checksumMismatch(let expected, let actual):
            return "Checksum mismatch: expected \(expected), got \(actual)"
        case .fileSystemError(let message):
            return "File system error: \(message)"
        case .invalidResponse(let message):
            return "Invalid response: \(message)"
        }
    }
}

/// Manages downloading whisper-service binary from GitHub Releases
@MainActor
final class DownloadManager: ObservableObject {
    // MARK: - Published State

    @Published private(set) var state: DownloadState = .idle

    // MARK: - GitHub Release Configuration

    private let owner = "louzhixian"
    private let repo = "babble"
    private let version = "whisper-v1.0.0"
    private let binaryName = "whisper-service"
    private let checksumFileName = "whisper-service.sha256"

    // These URLs are constructed from compile-time constants, so force-unwrap is safe
    private var releaseBaseURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/\(owner)/\(repo)/releases/download/\(version)")!
    }

    private var binaryDownloadURL: URL {
        releaseBaseURL.appendingPathComponent(binaryName)
    }

    private var checksumDownloadURL: URL {
        releaseBaseURL.appendingPathComponent(checksumFileName)
    }

    // MARK: - Local Paths

    private let fileManager = FileManager.default

    var applicationSupportDirectory: URL {
        // Application Support directory always exists on macOS
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory not available")
        }
        return appSupport.appendingPathComponent("Babble")
    }

    var localBinaryPath: URL {
        applicationSupportDirectory.appendingPathComponent(binaryName)
    }

    var localChecksumPath: URL {
        applicationSupportDirectory.appendingPathComponent(checksumFileName)
    }

    // MARK: - Retry Configuration

    let maxRetries = 3
    private var currentRetryCount = 0

    // MARK: - URLSession

    private let session: URLSession

    // MARK: - Initialization

    init(session: URLSession? = nil) {
        // Use custom session with extended timeout for large downloads
        if let session = session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 300  // 5 minutes per request
            config.timeoutIntervalForResource = 3600  // 1 hour total for download
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Public Methods

    /// Quick check if download is needed (only checks file existence, not checksum)
    /// This is safe to call on main thread during app launch.
    /// Full checksum verification is done in downloadIfNeeded() if files exist.
    func isDownloadNeeded() -> Bool {
        // Quick check: if both files exist, assume we're good
        // Full verification happens async in downloadIfNeeded()
        let binaryExists = fileManager.fileExists(atPath: localBinaryPath.path)
        let checksumExists = fileManager.fileExists(atPath: localChecksumPath.path)
        return !binaryExists || !checksumExists
    }

    /// Full async verification including checksum comparison
    /// Runs checksum computation in background to avoid blocking main thread
    private func verifyChecksumAsync() async -> Bool {
        let binaryPath = localBinaryPath
        let checksumPath = localChecksumPath

        return await Task.detached {
            // Check if files exist
            let fm = FileManager.default
            guard fm.fileExists(atPath: binaryPath.path),
                  fm.fileExists(atPath: checksumPath.path) else {
                return false
            }

            // Load expected checksum
            guard let data = try? Data(contentsOf: checksumPath),
                  let checksumString = String(data: data, encoding: .utf8) else {
                return false
            }

            // Parse checksum (format: "hash  filename" or just "hash")
            let expectedChecksum = checksumString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .components(separatedBy: .whitespaces)
                .first ?? ""

            guard expectedChecksum.count == 64 else {
                return false
            }

            // Compute actual checksum
            guard let binaryData = try? Data(contentsOf: binaryPath) else {
                return false
            }

            let digest = SHA256.hash(data: binaryData)
            let actualChecksum = digest.map { String(format: "%02x", $0) }.joined()

            return expectedChecksum.lowercased() == actualChecksum.lowercased()
        }.value
    }

    /// Downloads the binary if needed, with progress tracking
    func downloadIfNeeded() async {
        // Quick check passed, but do full async verification if files exist
        if !isDownloadNeeded() {
            // Files exist, verify checksum in background
            state = .verifying
            if await verifyChecksumAsync() {
                // Ensure binary is executable (manual downloads may have 0644 permissions)
                do {
                    try makeExecutable()
                } catch {
                    // Non-fatal: binary might already be executable
                }
                state = .completed
                return
            }
            // Checksum failed, need to re-download
        }

        currentRetryCount = 0
        await performDownload()
    }

    /// Retries a failed download (up to maxRetries times)
    func retry() async {
        guard case .failed(_, let retries) = state, retries < maxRetries else { return }
        currentRetryCount += 1
        await performDownload()
    }

    /// Returns the GitHub releases page URL for manual download
    var manualDownloadURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/\(owner)/\(repo)/releases/tag/\(version)")!
    }

    // MARK: - Private Methods

    private func performDownload() async {
        do {
            // Ensure directory exists
            state = .checking
            try ensureDirectoryExists()

            // Download checksum file first
            let expectedChecksum = try await downloadChecksum()

            // Download binary with progress
            try await downloadBinary()

            // Verify checksum
            state = .verifying
            let actualChecksum = try computeChecksum(for: localBinaryPath)

            guard expectedChecksum == actualChecksum else {
                throw DownloadError.checksumMismatch(expected: expectedChecksum, actual: actualChecksum)
            }

            // Store checksum for future verification
            try storeChecksum(expectedChecksum)

            // Make binary executable
            try makeExecutable()

            state = .completed

        } catch let error as DownloadError {
            state = .failed(error: error, retryCount: currentRetryCount)
        } catch let urlError as URLError {
            let message = urlError.localizedDescription
            state = .failed(error: .networkError(message), retryCount: currentRetryCount)
        } catch {
            state = .failed(error: .fileSystemError(error.localizedDescription), retryCount: currentRetryCount)
        }
    }

    private func ensureDirectoryExists() throws {
        if !fileManager.fileExists(atPath: applicationSupportDirectory.path) {
            do {
                try fileManager.createDirectory(
                    at: applicationSupportDirectory,
                    withIntermediateDirectories: true
                )
            } catch {
                throw DownloadError.fileSystemError("Failed to create directory: \(error.localizedDescription)")
            }
        }
    }

    private func downloadChecksum() async throws -> String {
        let (data, response) = try await session.data(from: checksumDownloadURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse("Not an HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw DownloadError.invalidResponse("HTTP \(httpResponse.statusCode)")
        }

        guard let checksumString = String(data: data, encoding: .utf8) else {
            throw DownloadError.invalidResponse("Invalid checksum format")
        }

        // Checksum file format: "checksum  filename" or just "checksum"
        let checksum = checksumString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .first ?? ""

        guard checksum.count == 64 else {
            throw DownloadError.invalidResponse("Invalid checksum length: \(checksum.count)")
        }

        return checksum.lowercased()
    }

    private func downloadBinary() async throws {
        let url = binaryDownloadURL
        let destinationPath = localBinaryPath

        state = .downloading(progress: 0, downloadedBytes: 0, totalBytes: 0)

        // Use URLSessionDownloadTask for efficient large file downloads
        // This avoids per-byte iteration overhead
        let delegate = DownloadProgressDelegate { [weak self] progress, downloaded, total in
            Task { @MainActor in
                self?.state = .downloading(progress: progress, downloadedBytes: downloaded, totalBytes: total)
            }
        }

        let delegateSession = URLSession(
            configuration: session.configuration,
            delegate: delegate,
            delegateQueue: nil
        )

        defer {
            delegateSession.invalidateAndCancel()
        }

        // Download to temporary file, then move to destination
        let (tempURL, response) = try await delegateSession.download(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse("Not an HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw DownloadError.invalidResponse("HTTP \(httpResponse.statusCode)")
        }

        // Move downloaded file to destination
        let fm = FileManager.default
        try? fm.removeItem(at: destinationPath)
        try fm.moveItem(at: tempURL, to: destinationPath)

        // Final progress update
        let totalBytes = httpResponse.expectedContentLength
        state = .downloading(progress: 1.0, downloadedBytes: totalBytes, totalBytes: totalBytes)
    }

    private func computeChecksum(for url: URL) throws -> String {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw DownloadError.fileSystemError("Failed to read file for checksum: \(error.localizedDescription)")
        }

        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func loadStoredChecksum() throws -> String {
        let data = try Data(contentsOf: localChecksumPath)
        guard let checksumString = String(data: data, encoding: .utf8) else {
            throw DownloadError.fileSystemError("Invalid stored checksum format")
        }

        // Checksum file format: "checksum  filename" or just "checksum"
        // Parse the first token to handle both formats (same as downloadChecksum)
        let checksum = checksumString
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces)
            .first ?? ""

        guard checksum.count == 64 else {
            throw DownloadError.fileSystemError("Invalid stored checksum length: \(checksum.count)")
        }

        return checksum.lowercased()
    }

    private func storeChecksum(_ checksum: String) throws {
        do {
            try checksum.write(to: localChecksumPath, atomically: true, encoding: .utf8)
        } catch {
            throw DownloadError.fileSystemError("Failed to store checksum: \(error.localizedDescription)")
        }
    }

    private func makeExecutable() throws {
        do {
            try fileManager.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: localBinaryPath.path
            )
        } catch {
            throw DownloadError.fileSystemError("Failed to make binary executable: \(error.localizedDescription)")
        }
    }
}

// MARK: - Download Progress Delegate

/// Delegate for tracking download progress with URLSessionDownloadTask
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    private let onProgress: @Sendable (Double, Int64, Int64) -> Void

    init(onProgress: @escaping @Sendable (Double, Int64, Int64) -> Void) {
        self.onProgress = onProgress
        super.init()
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = totalBytesExpectedToWrite > 0
            ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
            : 0
        onProgress(progress, totalBytesWritten, totalBytesExpectedToWrite)
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didFinishDownloadingTo _: URL
    ) {
        // File handling is done in the async download completion
    }
}
