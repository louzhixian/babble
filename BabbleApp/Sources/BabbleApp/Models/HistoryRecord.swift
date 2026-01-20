import Foundation

struct HistoryRecord: Identifiable, Equatable {
    let id: String
    let timestamp: Date
    let rawText: String
    let refinedText: String
    let refined: Bool
    let targetAppName: String?
    var editedText: String?
    var editedVariant: HistoryTextVariant?

    static func sample(id: String) -> HistoryRecord {
        HistoryRecord(
            id: id,
            timestamp: Date(),
            rawText: "raw",
            refinedText: "refined",
            refined: false,
            targetAppName: nil,
            editedText: nil,
            editedVariant: nil
        )
    }
}
