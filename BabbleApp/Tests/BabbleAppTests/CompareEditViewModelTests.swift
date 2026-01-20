import XCTest
@testable import BabbleApp

@MainActor
final class CompareEditViewModelTests: XCTestCase {
    func testDefaultsToRefinedText() {
        let record = HistoryRecord.sample(id: "1")
        let model = CompareEditViewModel(record: record)
        XCTAssertEqual(model.editingText, record.refinedText)
    }

    func testUpdateReplacesRecordAndEditingText() {
        let record = HistoryRecord.sample(id: "1")
        var next = HistoryRecord.sample(id: "2")
        next = HistoryRecord(
            id: next.id,
            timestamp: next.timestamp,
            rawText: next.rawText,
            refinedText: "new refined",
            refineOptions: next.refineOptions,
            targetAppName: next.targetAppName,
            editedText: next.editedText
        )

        let model = CompareEditViewModel(record: record)
        model.editingText = "user edit"
        model.update(record: next)

        XCTAssertEqual(model.record.id, next.id)
        XCTAssertEqual(model.editingText, "new refined")
    }
}
