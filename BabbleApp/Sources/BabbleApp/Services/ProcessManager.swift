// BabbleApp/Sources/BabbleApp/Services/ProcessManager.swift

import Foundation

actor WhisperProcessManager {
    private var process: Process?
    private var isRunning = false

    private let binaryPath: URL
    private var healthURL: URL
    private let host: String
    private var port: Int
    private let session: URLSession

    // Readiness check configuration
    private let maxStartupWaitSeconds = 60
    private let healthCheckIntervalNanoseconds: UInt64 = 500_000_000  // 0.5 seconds

    init(host: String = "127.0.0.1", port: Int = 8787) {
        // Set up health check URL and session
        self.host = host
        self.port = port
        // URL format is controlled (http://host:port/health), so force-unwrap is safe
        // swiftlint:disable:next force_unwrapping
        healthURL = URL(string: "http://\(host):\(port)/health")!
        session = URLSession.shared

        // Binary is downloaded to Application Support directory
        let fileManager = FileManager.default
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Application Support directory not available")
        }
        binaryPath = appSupport
            .appendingPathComponent("Babble")
            .appendingPathComponent("whisper-service")
    }

    func updatePort(_ port: Int) {
        guard self.port != port else { return }
        stop()
        self.port = port
        // swiftlint:disable:next force_unwrapping
        healthURL = URL(string: "http://\(host):\(port)/health")!
    }

    func currentPort() -> Int {
        port
    }

    func currentHealthURL() -> URL {
        healthURL
    }

    /// Checks if the whisper-service binary is installed
    func isBinaryInstalled() -> Bool {
        FileManager.default.fileExists(atPath: binaryPath.path)
    }

    func start() async throws {
        // If process crashed, reset state
        if isRunning && !(process?.isRunning ?? false) {
            isRunning = false
            process = nil
        }

        guard !isRunning else { return }

        // Check if service is already running externally
        if await checkHealth() {
            isRunning = true
            return
        }

        guard isBinaryInstalled() else {
            throw ProcessManagerError.binaryNotInstalled(binaryPath.path)
        }

        let process = Process()
        process.executableURL = binaryPath
        var environment = ProcessInfo.processInfo.environment
        environment["BABBLE_WHISPER_PORT"] = String(port)
        process.environment = environment

        // Discard output to prevent pipe buffer from filling and blocking process
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        self.process = process
        isRunning = true

        // Wait for service to be ready by polling /health endpoint
        try await waitForServiceReady()
    }

    private func waitForServiceReady() async throws {
        let startTime = Date()
        let deadline = startTime.addingTimeInterval(TimeInterval(maxStartupWaitSeconds))

        while Date() < deadline {
            // Check if process is still running
            guard process?.isRunning == true else {
                isRunning = false
                throw ProcessManagerError.startFailed("Process exited unexpectedly")
            }

            // Try health check
            if await checkHealth() {
                return
            }

            // Wait before retrying
            try await Task.sleep(nanoseconds: healthCheckIntervalNanoseconds)
        }

        // Timeout reached
        stop()
        throw ProcessManagerError.startFailed("Service did not become ready within \(maxStartupWaitSeconds) seconds")
    }

    private func checkHealth() async -> Bool {
        do {
            let (_, response) = try await session.data(from: healthURL)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            // Connection refused or other error - service not ready yet
        }
        return false
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    func ensureRunning() async throws {
        if !running {
            try await start()
        }
    }

    var running: Bool {
        isRunning && (process?.isRunning ?? false)
    }

    /// Preload the model (downloads if not cached, loads into memory)
    /// Call this after start() to ensure model is ready before first use
    func warmup() async throws {
        try await ensureRunning()

        let warmupURL = URL(string: "http://\(host):\(port)/warmup")!
        var request = URLRequest(url: warmupURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 600  // 10 minutes for model download

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ProcessManagerError.startFailed("Failed to warmup model")
        }

        // Parse response to check status
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let status = json["status"] as? String {
            if status == "loaded" || status == "already_loaded" {
                return
            }
        }

        throw ProcessManagerError.startFailed("Unexpected warmup response")
    }
}

enum ProcessManagerError: Error, LocalizedError {
    case binaryNotInstalled(String)
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .binaryNotInstalled(let path):
            return "Whisper service binary not installed at: \(path)"
        case .startFailed(let message):
            return "Failed to start Whisper service: \(message)"
        }
    }
}
