import XCTest
@testable import BabbleApp

@MainActor
final class HistoryStoreTests: XCTestCase {
    func testKeepsNewestWhenExceedingLimit() {
        let store = HistoryStore(limit: 2)
        store.append(HistoryRecord.sample(id: "1"))
        store.append(HistoryRecord.sample(id: "2"))
        store.append(HistoryRecord.sample(id: "3"))

        XCTAssertEqual(store.records.map { $0.id }, ["3", "2"])
    }
}
