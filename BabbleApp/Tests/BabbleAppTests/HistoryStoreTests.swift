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

    func testTrimsWhenLimitIsReduced() {
        let store = HistoryStore(limit: 3)
        store.append(HistoryRecord.sample(id: "1"))
        store.append(HistoryRecord.sample(id: "2"))
        store.append(HistoryRecord.sample(id: "3"))

        store.updateLimit(2)

        XCTAssertEqual(store.records.map { $0.id }, ["3", "2"])
    }

    func testUpdatesEditedTextForRecord() {
        let store = HistoryStore(limit: 2)
        store.append(HistoryRecord.sample(id: "1"))

        let updated = store.updateEditedText(for: "1", editedText: "edited", editedVariant: .raw)

        XCTAssertEqual(updated?.editedText, "edited")
        XCTAssertEqual(updated?.editedVariant, .raw)
        XCTAssertEqual(store.records.first?.editedText, "edited")
    }
}
