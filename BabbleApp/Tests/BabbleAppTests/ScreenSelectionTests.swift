import CoreGraphics
import XCTest
@testable import BabbleApp

final class ScreenSelectionTests: XCTestCase {
    func testScreenFrameContainingUsesWindowCenter() {
        let left = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let right = CGRect(x: 1000, y: 0, width: 1000, height: 800)
        let window = CGRect(x: 1200, y: 100, width: 300, height: 200)

        let result = ScreenSelection.screenFrameContaining(rect: window, screens: [left, right])

        XCTAssertEqual(result, right)
    }
}
