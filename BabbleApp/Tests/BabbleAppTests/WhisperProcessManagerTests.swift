import XCTest
@testable import BabbleApp

final class WhisperProcessManagerTests: XCTestCase {
    func testUpdatePortRefreshesHealthURL() async {
        let manager = WhisperProcessManager(port: 9000)

        let initialPort = await manager.currentPort()
        let initialHealthURL = await manager.currentHealthURL().absoluteString
        XCTAssertEqual(initialPort, 9000)
        XCTAssertEqual(initialHealthURL, "http://127.0.0.1:9000/health")

        await manager.updatePort(8000)

        let updatedPort = await manager.currentPort()
        let updatedHealthURL = await manager.currentHealthURL().absoluteString
        XCTAssertEqual(updatedPort, 8000)
        XCTAssertEqual(updatedHealthURL, "http://127.0.0.1:8000/health")
    }
}
