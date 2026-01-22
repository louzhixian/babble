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

    private let maxRetries = 3
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

    /// Checks if download is needed (binary doesn't exist or checksum mismatch)
    func isDownloadNeeded() -> Bool {
        // Check if binary exists
        guard fileManager.fileExists(atPath: localBinaryPath.path) else {
            return true
        }

        // Check if checksum file exists
        guard fileManager.fileExists(atPath: localChecksumPath.path) else {
            return true
        }

        // Verify checksum matches
        do {
            let expectedChecksum = try loadStoredChecksum()
            let actualChecksum = try computeChecksum(for: localBinaryPath)
            return expectedChecksum != actualChecksum
        } catch {
            return true
        }
    }

    /// Downloads the binary if needed, with progress tracking
    func downloadIfNeeded() async {
        guard isDownloadNeeded() else {
            state = .completed
            return
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
        let (bytes, response) = try await session.bytes(from: binaryDownloadURL)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DownloadError.invalidResponse("Not an HTTP response")
        }

        guard httpResponse.statusCode == 200 else {
            throw DownloadError.invalidResponse("HTTP \(httpResponse.statusCode)")
        }

        let totalBytes = httpResponse.expectedContentLength
        var downloadedBytes: Int64 = 0
        var data = Data()

        // Reserve capacity if we know the size
        if totalBytes > 0 {
            data.reserveCapacity(Int(totalBytes))
        }

        state = .downloading(progress: 0, downloadedBytes: 0, totalBytes: totalBytes)

        for try await byte in bytes {
            data.append(byte)
            downloadedBytes += 1

            // Update progress every 100KB to avoid too frequent updates
            if downloadedBytes % (100 * 1024) == 0 {
                let progress = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0
                state = .downloading(progress: progress, downloadedBytes: downloadedBytes, totalBytes: totalBytes)
            }
        }

        // Final progress update
        let progress = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 1.0
        state = .downloading(progress: progress, downloadedBytes: downloadedBytes, totalBytes: totalBytes)

        // Write to file
        do {
            try data.write(to: localBinaryPath)
        } catch {
            throw DownloadError.fileSystemError("Failed to write binary: \(error.localizedDescription)")
        }
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
        guard let checksum = String(data: data, encoding: .utf8) else {
            throw DownloadError.fileSystemError("Invalid stored checksum format")
        }
        return checksum.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
