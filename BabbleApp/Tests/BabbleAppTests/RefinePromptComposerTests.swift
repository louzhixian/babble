import XCTest
@testable import BabbleApp

final class RefinePromptComposerTests: XCTestCase {
    func testCustomPromptOverridesDefault() {
        let composer = RefinePromptComposer(customPrompts: [.correct: "自定义纠错"])
        let prompt = composer.prompt(for: [.correct])
        XCTAssertEqual(prompt, "自定义纠错")
    }
}
