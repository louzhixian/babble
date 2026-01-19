import AppKit
import XCTest
@testable import BabbleApp

final class FloatingPanelStateTests: XCTestCase {
    func testMicColorIsGreenWhenRecording() {
        let state = FloatingPanelState(status: .recording, message: nil)
        XCTAssertEqual(state.micColor, NSColor.systemGreen)
    }
}
