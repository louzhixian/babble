// BabbleApp/Sources/BabbleApp/Services/WhisperClient.swift

import Foundation

struct TranscriptionResult: Codable {
    let text: String
    let segments: [Segment]?
    let language: String?
    let processingTime: Double?

    enum CodingKeys: String, CodingKey {
        case text
        case segments
        case language
        case processingTime = "processing_time"
    }

    struct Segment: Codable {
        let start: Double?
        let end: Double?
        let text: String?
    }
}

struct HealthResponse: Codable {
    let status: String
    let model: String
    let modelLoaded: Bool?

    enum CodingKeys: String, CodingKey {
        case status
        case model
        case modelLoaded = "model_loaded"
    }
}

struct WarmupResponse: Codable {
    let status: String
    let model: String
}

enum WhisperClientError: Error, LocalizedError {
    case serverNotRunning
    case invalidResponse
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Whisper service is not running"
        case .invalidResponse:
            return "Invalid response from Whisper service"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

actor WhisperClient {
    private let baseURL: URL
    private let session: URLSession

    init(host: String = "127.0.0.1", port: Int = 8787) {
        self.baseURL = URL(string: "http://\(host):\(port)")!
        self.session = URLSession.shared
    }

    func checkHealth() async throws -> HealthResponse {
        let url = baseURL.appendingPathComponent("health")
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhisperClientError.serverNotRunning
        }

        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    /// Trigger model preloading (downloads if not cached, loads into memory)
    /// This may take a while on first run (~1.5GB download)
    func warmup() async throws -> WarmupResponse {
        let url = baseURL.appendingPathComponent("warmup")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 600  // 10 minutes for model download

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhisperClientError.serverNotRunning
        }

        return try JSONDecoder().decode(WarmupResponse.self, from: data)
    }

    func transcribe(audioURL: URL, language: String? = nil) async throws -> TranscriptionResult {
        let url = baseURL.appendingPathComponent("transcribe")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add language only if explicitly specified (otherwise use server config default)
        if let language = language {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(language)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperClientError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperClientError.transcriptionFailed(errorMessage)
        }

        return try JSONDecoder().decode(TranscriptionResult.self, from: data)
    }
}
