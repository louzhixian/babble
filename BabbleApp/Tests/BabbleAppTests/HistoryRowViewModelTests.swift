import XCTest
@testable import BabbleApp

@MainActor
final class HistoryRowViewModelTests: XCTestCase {
    func testEditingDefaultsToSelectedVariant() {
        let record = HistoryRecord.sample(id: "1")
        let model = HistoryRowViewModel(record: record)
        model.selectedVariant = .refined
        model.beginEditing()
        XCTAssertEqual(model.editingText, record.refinedText)
    }

    func testFinishEditingExitsEditMode() {
        let record = HistoryRecord.sample(id: "1")
        let model = HistoryRowViewModel(record: record)
        model.beginEditing()
        model.finishEditing()
        XCTAssertFalse(model.isEditing)
    }

    func testSelectedTextPrefersEditedTextForRefined() {
        var record = HistoryRecord.sample(id: "1")
        record.editedText = "edited text"
        let model = HistoryRowViewModel(record: record)
        model.selectedVariant = .refined

        XCTAssertEqual(model.selectedText, "edited text")
    }
}
