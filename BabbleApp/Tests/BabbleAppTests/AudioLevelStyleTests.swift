import AppKit
import XCTest
@testable import BabbleApp

final class AudioLevelStyleTests: XCTestCase {
    func testBarColorIsGreen() {
        XCTAssertEqual(AudioLevelStyle.barColor, NSColor.systemGreen)
    }
}
