import Foundation

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [HistoryRecord] = []
    private let limit: Int

    init(limit: Int) {
        self.limit = limit
    }

    func append(_ record: HistoryRecord) {
        records.insert(record, at: 0)
        if records.count > limit {
            records = Array(records.prefix(limit))
        }
    }
}
