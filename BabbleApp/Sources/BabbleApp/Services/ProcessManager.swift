// BabbleApp/Sources/BabbleApp/Services/ProcessManager.swift

import Foundation

actor WhisperProcessManager {
    private var process: Process?
    private var isRunning = false

    private let whisperServicePath: URL
    private let pythonPath: String

    init() {
        // Locate whisper-service relative to app bundle or development path
        let bundle = Bundle.main
        if let resourcePath = bundle.resourcePath {
            whisperServicePath = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("whisper-service")
        } else {
            // Development fallback
            whisperServicePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .deletingLastPathComponent()
                .appendingPathComponent("whisper-service")
        }

        // Find Python
        pythonPath = "/usr/bin/env"
    }

    func start() async throws {
        // If process crashed, reset state
        if isRunning && !(process?.isRunning ?? false) {
            isRunning = false
            process = nil
        }

        guard !isRunning else { return }

        let serverPath = whisperServicePath.appendingPathComponent("server.py")

        guard FileManager.default.fileExists(atPath: serverPath.path) else {
            throw ProcessManagerError.serviceNotFound(serverPath.path)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["python3", serverPath.path]
        process.currentDirectoryURL = whisperServicePath

        // Capture output for debugging
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        self.process = process
        isRunning = true

        // Wait a moment for server to start
        try await Task.sleep(nanoseconds: 2_000_000_000)
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
