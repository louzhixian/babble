import XCTest
@testable import BabbleApp

@MainActor
final class MainWindowRoutingTests: XCTestCase {
    func testDefaultRouteIsHistory() {
        let router = MainWindowRouter()
        XCTAssertEqual(router.selection, .history)
    }
}
