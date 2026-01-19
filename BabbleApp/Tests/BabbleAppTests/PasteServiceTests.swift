import XCTest
@testable import BabbleApp

private struct FailingEventPoster: EventPoster {
    func postPaste() -> Bool {
        false
    }
}

final class PasteServiceTests: XCTestCase {
    func testPasteReturnsFailureWhenEventTapDenied() {
        let service = PasteService(eventPoster: FailingEventPoster())
        XCTAssertFalse(service.pasteFromClipboard())
    }
}
