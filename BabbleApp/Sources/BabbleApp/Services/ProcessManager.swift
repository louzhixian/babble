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

        // Kill any stale whisper-service processes before starting
        // This ensures we always run the latest downloaded binary
        await killStaleProcesses()

        // Check if service is already running (shouldn't be after killing stale processes)
        if await checkHealth() {
            Log.process.debug("Service already running on port \(self.port)")
            isRunning = true
            return
        }

        guard isBinaryInstalled() else {
            throw ProcessManagerError.binaryNotInstalled(binaryPath.path)
        }

        Log.process.info("Starting binary at \(self.binaryPath.path)")
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

    /// Kill any stale whisper-service processes that weren't started by this ProcessManager
    /// This ensures we always use the latest downloaded binary
    private func killStaleProcesses() async {
        // Use specific pattern to avoid killing unrelated processes
        // Match only processes running from our Application Support directory
        let targetPattern = binaryPath.path

        // Run blocking pkill in detached task to avoid blocking the actor
        await Task.detached {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
            task.arguments = ["-f", targetPattern]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()

                let exitCode = task.terminationStatus
                if exitCode == 0 {
                    Log.process.debug("Killed stale whisper-service processes")
                } else if exitCode == 1 {
                    Log.process.debug("No stale whisper-service processes found")
                } else {
                    Log.process.warning("pkill returned unexpected exit code: \(exitCode)")
                }
            } catch {
                Log.process.error("pkill failed to launch: \(error.localizedDescription)")
            }
        }.value

        // Wait for processes to fully terminate
        try? await Task.sleep(nanoseconds: 500_000_000)
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
        Log.process.debug("warmup() called, ensuring service is running...")
        try await ensureRunning()
        Log.process.debug("Service is running, calling warmup endpoint...")

        // Use a dedicated session with long timeout for model download
        let warmupConfig = URLSessionConfiguration.default
        warmupConfig.timeoutIntervalForRequest = 600  // 10 minutes
        warmupConfig.timeoutIntervalForResource = 600
        let warmupSession = URLSession(configuration: warmupConfig)
        defer { warmupSession.invalidateAndCancel() }

        let warmupURL = URL(string: "http://\(host):\(port)/warmup")!
        var request = URLRequest(url: warmupURL)
        request.httpMethod = "POST"

        Log.process.debug("POST \(warmupURL)")

        do {
            let (data, response) = try await warmupSession.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                Log.process.error("Warmup: not an HTTP response")
                throw ProcessManagerError.startFailed("Warmup: not an HTTP response")
            }

            Log.process.debug("Warmup response status: \(httpResponse.statusCode)")

            let bodyStr = String(data: data, encoding: .utf8) ?? "no body"
            Log.process.debug("Warmup response body: \(bodyStr)")

            guard httpResponse.statusCode == 200 else {
                throw ProcessManagerError.startFailed("Warmup failed with HTTP \(httpResponse.statusCode): \(bodyStr)")
            }

            // Parse response to check status
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String {
                Log.process.info("Warmup status: \(status)")
                if status == "loaded" || status == "already_loaded" {
                    return
                }
            }

            throw ProcessManagerError.startFailed("Unexpected warmup response: \(bodyStr)")
        } catch let error as ProcessManagerError {
            throw error
        } catch let urlError as URLError {
            Log.process.error("Warmup URLError: \(urlError.code.rawValue) - \(urlError.localizedDescription)")
            if urlError.code == .timedOut {
                throw ProcessManagerError.startFailed("Warmup timed out - model download may still be in progress")
            }
            throw ProcessManagerError.startFailed("Warmup request failed: \(urlError.localizedDescription)")
        } catch {
            Log.process.error("Warmup error: \(error.localizedDescription)")
            throw ProcessManagerError.startFailed("Warmup request failed: \(error.localizedDescription)")
        }
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
