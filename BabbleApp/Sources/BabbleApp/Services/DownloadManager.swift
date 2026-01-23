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
    case downloadComplete  // Download finished, waiting for user confirmation
    case completed  // User confirmed, ready to proceed

    static func == (lhs: DownloadState, rhs: DownloadState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.checking, .checking),
             (.verifying, .verifying),
             (.downloadComplete, .downloadComplete),
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
    private let version = "whisper-v1.0.9"
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

    /// Full async verification including checksum comparison against REMOTE checksum
    /// This ensures we re-download when a new version is released
    /// Runs checksum computation in background to avoid blocking main thread
    private func verifyChecksumAsync() async -> Bool {
        let binaryPath = localBinaryPath

        // First check if binary exists locally
        guard fileManager.fileExists(atPath: binaryPath.path) else {
            print("DownloadManager: Binary not found at \(binaryPath.path)")
            return false
        }

        // Fetch the REMOTE checksum to compare against
        // This ensures we detect when a new version is released
        let remoteChecksum: String
        do {
            remoteChecksum = try await downloadChecksum()
            print("DownloadManager: Remote checksum: \(remoteChecksum)")
        } catch {
            print("DownloadManager: Failed to fetch remote checksum: \(error)")
            // Network failure - fall back to local validation if available
            // This prevents unnecessary re-downloads during offline usage
            if let localStoredChecksum = try? loadStoredChecksum() {
                if let localChecksum = try? await computeChecksumAsync(for: binaryPath),
                   localChecksum == localStoredChecksum {
                    print("DownloadManager: Network unavailable but local checksum valid")
                    return true
                }
            }
            return false
        }

        // Compute local binary checksum in background
        let localChecksum: String
        do {
            localChecksum = try await computeChecksumAsync(for: binaryPath)
            print("DownloadManager: Local checksum: \(localChecksum)")
        } catch {
            print("DownloadManager: Failed to compute local checksum: \(error)")
            return false
        }

        let matches = remoteChecksum.lowercased() == localChecksum.lowercased()
        print("DownloadManager: Checksum match: \(matches)")
        return matches
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

    /// Starts download unconditionally (called when we know download is needed)
    /// This avoids race conditions where files might appear between checks
    func startDownload() async {
        currentRetryCount = 0
        await performDownload()
    }

    /// Retries a failed download (up to maxRetries times)
    func retry() async {
        guard case .failed(_, let retries) = state, retries < maxRetries else { return }
        currentRetryCount += 1
        await performDownload()
    }

    /// Verifies existing binary in background
    /// Returns true if binary is valid and ready to use, false if repair is needed
    func verifyAndRepairInBackground() async -> Bool {
        // Verify checksum in background
        if await verifyChecksumAsync() {
            // Binary is valid, ensure it's executable
            do {
                try makeExecutable()
            } catch {
                // Non-fatal: binary might already be executable
            }
            return true
        }

        // Checksum failed - binary is corrupted
        return false
    }

    /// Returns the GitHub releases page URL for manual download
    var manualDownloadURL: URL {
        // swiftlint:disable:next force_unwrapping
        URL(string: "https://github.com/\(owner)/\(repo)/releases/tag/\(version)")!
    }

    /// Called when user confirms download completion to proceed with permissions
    func confirmDownloadComplete() {
        guard case .downloadComplete = state else { return }
        state = .completed
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
            let actualChecksum = try await computeChecksumAsync(for: localBinaryPath)

            guard expectedChecksum == actualChecksum else {
                throw DownloadError.checksumMismatch(expected: expectedChecksum, actual: actualChecksum)
            }

            // Store checksum for future verification
            try storeChecksum(expectedChecksum)

            // Make binary executable
            try makeExecutable()

            state = .downloadComplete

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

        // First, get the actual file size via HEAD request (following redirects)
        // GitHub releases redirect to a CDN, and the original URL doesn't have Content-Length
        print("DownloadManager: Starting download from \(url)")
        let expectedSize = await getFileSizeViaHead(url: url)
        print("DownloadManager: Expected file size: \(expectedSize)")

        // Use URLSessionDownloadTask for efficient large file downloads
        // This avoids per-byte iteration overhead
        let delegate = DownloadProgressDelegate(expectedSize: expectedSize, onProgress: { [weak self] progress, downloaded, total in
            Task { @MainActor in
                self?.state = .downloading(progress: progress, downloadedBytes: downloaded, totalBytes: total)
            }
        })

        // Use a dedicated OperationQueue to ensure delegate callbacks are delivered
        let delegateQueue = OperationQueue()
        delegateQueue.name = "DownloadProgress"
        delegateQueue.maxConcurrentOperationCount = 1

        let delegateSession = URLSession(
            configuration: session.configuration,
            delegate: delegate,
            delegateQueue: delegateQueue
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

        // Final progress update - use actual file size if HEAD request succeeded
        let totalBytes = expectedSize > 0 ? expectedSize : httpResponse.expectedContentLength
        state = .downloading(progress: 1.0, downloadedBytes: totalBytes, totalBytes: totalBytes)
    }

    /// Computes SHA256 checksum in background to avoid blocking main thread
    private func computeChecksumAsync(for url: URL) async throws -> String {
        let filePath = url
        return try await Task.detached {
            let data: Data
            do {
                data = try Data(contentsOf: filePath)
            } catch {
                throw DownloadError.fileSystemError("Failed to read file for checksum: \(error.localizedDescription)")
            }

            let digest = SHA256.hash(data: data)
            return digest.map { String(format: "%02x", $0) }.joined()
        }.value
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

    /// Get file size using a range request which is more reliable than HEAD for CDN URLs
    /// Range request returns Content-Range header with total file size
    private func getFileSizeViaHead(url: URL) async -> Int64 {
        print("DownloadManager: Getting file size for \(url)")

        // Use range request - more reliable than HEAD for GitHub CDN
        // Range: bytes=0-0 returns first byte and Content-Range: bytes 0-0/TOTAL_SIZE
        var rangeRequest = URLRequest(url: url)
        rangeRequest.httpMethod = "GET"
        rangeRequest.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        rangeRequest.timeoutInterval = 30

        do {
            // URLSession follows redirects automatically for GET requests
            let (_, response) = try await session.data(for: rangeRequest)
            if let httpResponse = response as? HTTPURLResponse {
                print("DownloadManager: Range response status: \(httpResponse.statusCode)")

                // Check Content-Range header: "bytes 0-0/229615504"
                if let contentRange = httpResponse.value(forHTTPHeaderField: "Content-Range") {
                    print("DownloadManager: Content-Range: \(contentRange)")
                    if let slashIndex = contentRange.lastIndex(of: "/"),
                       let size = Int64(contentRange[contentRange.index(after: slashIndex)...]) {
                        print("DownloadManager: File size from range request: \(size)")
                        return size
                    }
                }

                // Fallback to Content-Length if available
                let size = httpResponse.expectedContentLength
                if size > 0 {
                    print("DownloadManager: File size from Content-Length: \(size)")
                    return size
                }
            }
        } catch {
            print("DownloadManager: Range request failed: \(error)")
        }

        print("DownloadManager: Could not determine file size")
        return -1
    }
}

// MARK: - Download Progress Delegate

/// Delegate for tracking download progress with URLSessionDownloadTask
private final class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double, Int64, Int64) -> Void
    private let lock = NSLock()
    private var _lastUpdateTime: Date = .distantPast
    private let expectedSize: Int64  // From HEAD request, used when server doesn't provide Content-Length

    init(expectedSize: Int64 = -1, onProgress: @escaping @Sendable (Double, Int64, Int64) -> Void) {
        self.expectedSize = expectedSize
        self.onProgress = onProgress
        super.init()
        print("DownloadProgressDelegate: initialized with expectedSize=\(expectedSize)")
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didWriteData _: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        // Log first callback to confirm delegate is working
        if _lastUpdateTime == .distantPast {
            print("DownloadProgressDelegate: first callback - written=\(totalBytesWritten), expected=\(totalBytesExpectedToWrite)")
        }

        // Throttle updates to avoid overwhelming the main thread
        let now = Date()
        lock.lock()
        let shouldUpdate = now.timeIntervalSince(_lastUpdateTime) >= 0.1
        if shouldUpdate {
            _lastUpdateTime = now
        }
        lock.unlock()

        guard shouldUpdate else { return }

        // Use expectedSize from HEAD request if server doesn't provide Content-Length
        let totalBytes = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : expectedSize
        let progress = totalBytes > 0
            ? Double(totalBytesWritten) / Double(totalBytes)
            : 0
        print("DownloadProgressDelegate: progress=\(Int(progress * 100))%, written=\(totalBytesWritten), total=\(totalBytes)")
        onProgress(progress, totalBytesWritten, totalBytes)
    }

    func urlSession(
        _: URLSession,
        downloadTask _: URLSessionDownloadTask,
        didFinishDownloadingTo _: URL
    ) {
        // File handling is done in the async download completion
    }
}
