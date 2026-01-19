import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [HistoryRecord] = []
    private(set) var limit: Int

    init(limit: Int) {
        self.limit = limit
    }

    func append(_ record: HistoryRecord) {
        records.insert(record, at: 0)
        trimToLimit()
    }

    func updateLimit(_ limit: Int) {
        self.limit = limit
        trimToLimit()
    }

    func updateEditedText(
        for recordID: String,
        editedText: String?,
        editedVariant: HistoryTextVariant
    ) -> HistoryRecord? {
        guard let index = records.firstIndex(where: { $0.id == recordID }) else {
            return nil
        }
        var record = records[index]
        record.editedText = editedText
        record.editedVariant = editedVariant
        records[index] = record
        return record
    }

    private func trimToLimit() {
        if records.count > limit {
            records = Array(records.prefix(limit))
        }
    }
}
