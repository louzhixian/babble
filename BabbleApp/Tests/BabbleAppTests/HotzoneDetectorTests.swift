import CoreGraphics
import XCTest
@testable import BabbleApp

final class HotzoneDetectorTests: XCTestCase {
    func testDetectsBottomLeftHotzone() {
        let detector = HotzoneDetector(corner: .bottomLeft, inset: 32)
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        XCTAssertTrue(detector.isInside(point: CGPoint(x: 10, y: 10), in: screen))
    }
}
