import Foundation

struct HistoryRecord: Identifiable, Equatable {
    let id: String
    let timestamp: Date
    let rawText: String
    let refinedText: String
    let refineOptions: [RefineOption]
    let targetAppName: String?
    var editedText: String?

    static func sample(id: String) -> HistoryRecord {
        HistoryRecord(
            id: id,
            timestamp: Date(),
            rawText: "raw",
            refinedText: "refined",
            refineOptions: [],
            targetAppName: nil,
            editedText: nil
        )
    }
}
