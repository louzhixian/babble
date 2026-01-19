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

    private func trimToLimit() {
        if records.count > limit {
            records = Array(records.prefix(limit))
        }
    }
}
