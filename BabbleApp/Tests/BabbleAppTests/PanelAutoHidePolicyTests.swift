import XCTest
@testable import BabbleApp

final class PanelAutoHidePolicyTests: XCTestCase {
    func testShouldAutoHideAfterCompletionWhenPasteFailed() {
        let policy = PanelAutoHidePolicy()
        XCTAssertTrue(policy.shouldAutoHideAfterCompletion(pasteSucceeded: false))
    }

    func testShouldNotAutoHideAfterCompletionWhenPasteSucceeded() {
        let policy = PanelAutoHidePolicy()
        XCTAssertFalse(policy.shouldAutoHideAfterCompletion(pasteSucceeded: true))
    }
}
