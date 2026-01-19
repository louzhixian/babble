// BabbleApp/Sources/BabbleApp/Services/RefineService.swift

import Foundation
import FoundationModels

enum RefineMode: String, CaseIterable {
    case off = "关闭"
    case correct = "纠错"
    case punctuate = "标点"
    case polish = "润色"

    var prompt: String? {
        switch self {
        case .off:
            return nil
        case .correct:
            return "修正以下语音转写中的明显错误，保持原意和口吻，只输出修正后的文本："
        case .punctuate:
            return "修正以下语音转写中的错误并优化标点符号，保持原意，只输出修正后的文本："
        case .polish:
            return "将以下口语转写转为通顺的书面表达，保持原意，只输出修正后的文本："
        }
    }
}

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
    private var session: LanguageModelSession?

    func refine(text: String, mode: RefineMode) async throws -> String {
        // If mode is off, return original text
        guard let prompt = mode.prompt else {
            return text
        }

        // Check availability
        let availability = SystemLanguageModel.default.availability
        guard availability == .available else {
            throw RefineError.modelNotAvailable
        }

        // Create session if needed
        if session == nil {
            session = LanguageModelSession()
        }

        guard let session = session else {
            throw RefineError.modelNotAvailable
        }

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
