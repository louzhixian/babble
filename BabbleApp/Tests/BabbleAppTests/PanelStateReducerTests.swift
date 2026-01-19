import XCTest
@testable import BabbleApp

final class PanelStateReducerTests: XCTestCase {
    func testKeepsPasteFailedAfterDelay() {
        let reducer = PanelStateReducer()
        let state = FloatingPanelState(status: .pasteFailed, message: "你可以在目标位置粘贴")

        let result = reducer.finalPanelStateAfterDelay(
            pasteSucceeded: false,
            current: state
        )

        XCTAssertEqual(result.status, .pasteFailed)
    }
}
