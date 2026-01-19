import XCTest
@testable import BabbleApp

@MainActor
final class CompareEditViewModelTests: XCTestCase {
    func testDefaultsToRefinedText() {
        let record = HistoryRecord.sample(id: "1")
        let model = CompareEditViewModel(record: record)
        XCTAssertEqual(model.editingText, record.refinedText)
    }
}
