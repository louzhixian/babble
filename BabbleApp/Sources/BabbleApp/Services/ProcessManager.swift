// BabbleApp/Sources/BabbleApp/Services/ProcessManager.swift

import Foundation

actor WhisperProcessManager {
    private var process: Process?
    private var isRunning = false

    private let whisperServicePath: URL
    private let pythonPath: URL
    private let healthURL: URL
    private let session: URLSession

    // Readiness check configuration
    private let maxStartupWaitSeconds = 60
    private let healthCheckIntervalNanoseconds: UInt64 = 500_000_000  // 0.5 seconds

    init() {
        // Locate whisper-service relative to app bundle or development path
        let bundle = Bundle.main
        let fileManager = FileManager.default

        // Set up health check URL and session (common to both paths)
        healthURL = URL(string: "http://127.0.0.1:8787/health")!
        session = URLSession.shared

        // Try bundle resources first (for packaged .app)
        if let resourcePath = bundle.resourcePath {
            let bundledPath = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("whisper-service")
            if fileManager.fileExists(atPath: bundledPath.path) {
                whisperServicePath = bundledPath
                // Use venv python if available, otherwise system python
                let venvPython = bundledPath.appendingPathComponent(".venv/bin/python3")
                if fileManager.fileExists(atPath: venvPython.path) {
                    pythonPath = venvPython
                } else {
                    pythonPath = URL(fileURLWithPath: "/usr/bin/python3")
                }
                return
            }
        }

        // Development fallback: look for whisper-service relative to current directory
        // This handles swift run and scripts/dev.sh scenarios
        let devPath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .deletingLastPathComponent()
            .appendingPathComponent("whisper-service")
        whisperServicePath = devPath

        // Use venv python if available (dependencies are installed there)
        let venvPython = devPath.appendingPathComponent(".venv/bin/python3")
        if fileManager.fileExists(atPath: venvPython.path) {
            pythonPath = venvPython
        } else {
            pythonPath = URL(fileURLWithPath: "/usr/bin/python3")
        }
    }

    func start() async throws {
        // If process crashed, reset state
        if isRunning && !(process?.isRunning ?? false) {
            isRunning = false
            process = nil
        }

        guard !isRunning else { return }

        // Check if service is already running externally (e.g., started by dev.sh)
        if await checkHealth() {
            isRunning = true
            return
        }

        let serverPath = whisperServicePath.appendingPathComponent("server.py")

        guard FileManager.default.fileExists(atPath: serverPath.path) else {
            throw ProcessManagerError.serviceNotFound(serverPath.path)
        }

        let process = Process()
        process.executableURL = pythonPath
        process.arguments = [serverPath.path]
        process.currentDirectoryURL = whisperServicePath

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
}

enum ProcessManagerError: Error, LocalizedError {
    case serviceNotFound(String)
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .serviceNotFound(let path):
            return "Whisper service not found at: \(path)"
        case .startFailed(let message):
            return "Failed to start Whisper service: \(message)"
        }
    }
}
