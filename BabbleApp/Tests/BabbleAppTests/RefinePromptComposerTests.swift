import XCTest
@testable import BabbleApp

final class RefinePromptComposerTests: XCTestCase {
    func testPromptCompositionUsesFixedOrder() {
        let composer = RefinePromptComposer()
        let prompt = composer.prompt(for: [.polish, .correct])

        XCTAssertNotNil(prompt)
        XCTAssertTrue(prompt?.contains(RefineOption.correct.prompt) == true)
        XCTAssertTrue(prompt?.contains(RefineOption.polish.prompt) == true)
        XCTAssertLessThan(
            prompt!.range(of: RefineOption.correct.prompt)!.lowerBound,
            prompt!.range(of: RefineOption.polish.prompt)!.lowerBound
        )
    }
}
