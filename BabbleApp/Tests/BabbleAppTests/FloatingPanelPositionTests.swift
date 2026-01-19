import XCTest
@testable import BabbleApp

final class FloatingPanelPositionTests: XCTestCase {
    func testDisplayNameForTop() {
        XCTAssertEqual(FloatingPanelPosition.top.displayName, "上")
    }
}
