import XCTest
@testable import BabbleApp

@MainActor
final class HotzoneTriggerTests: XCTestCase {
    func testStopEmitsEndWhenTriggered() {
        var didEnd = false
        let trigger = HotzoneTrigger(
            corner: .bottomLeft,
            holdSeconds: 1.0,
            onTriggerStart: {},
            onTriggerEnd: {
                didEnd = true
            }
        )

        trigger.setStateForTesting(.triggered)
        trigger.stop()

        XCTAssertTrue(didEnd)
    }
}
