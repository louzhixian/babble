// BabbleApp/Sources/BabbleApp/Services/RefineService.swift

import Foundation
import FoundationModels

enum RefineError: Error, LocalizedError {
    case modelNotAvailable
    case refineFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Apple Foundation Model is not available on this device"
        case .refineFailed(let message):
            return "Refinement failed: \(message)"
        }
    }
}

actor RefineService {
    static let defaultPrompt = "将语音转写的口语文字整理为书面语。去除口语词（嗯、啊、就是、那个等）、删除重复内容、修复断句、添加标点。保持原意，只输出整理后的文字。"

    func refine(text: String, prompt: String) async throws -> String {
        // Check availability
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            throw RefineError.modelNotAvailable
        }

        // Create a fresh session for each request to avoid context accumulation
        // LanguageModelSession accumulates conversation history, which would
        // eventually exceed the context window limit
        let session = LanguageModelSession()

        let fullPrompt = "\(prompt)\n\n\(text)"

        do {
            let response = try await session.respond(to: fullPrompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw RefineError.refineFailed(error.localizedDescription)
        }
    }

    func checkAvailability() -> Bool {
        return SystemLanguageModel.default.availability == .available
    }
}
