import XCTest
@testable import BabbleApp

@MainActor
final class ForceTouchTriggerTests: XCTestCase {
    func testStopEmitsEndWhenTriggered() {
        var didEnd = false
        let trigger = ForceTouchTrigger(
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

    func testStopDoesNotEmitEndWhenIdle() {
        var didEnd = false
        let trigger = ForceTouchTrigger(
            holdSeconds: 1.0,
            onTriggerStart: {},
            onTriggerEnd: {
                didEnd = true
            }
        )

        trigger.setStateForTesting(.idle)
        trigger.stop()

        XCTAssertFalse(didEnd)
    }

    func testStopDoesNotEmitEndWhenPressing() {
        var didEnd = false
        let trigger = ForceTouchTrigger(
            holdSeconds: 1.0,
            onTriggerStart: {},
            onTriggerEnd: {
                didEnd = true
            }
        )

        trigger.setStateForTesting(.pressing(Date()))
        trigger.stop()

        XCTAssertFalse(didEnd)
    }
}
