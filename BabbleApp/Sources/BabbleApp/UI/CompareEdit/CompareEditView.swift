import SwiftUI

@MainActor
final class CompareEditViewModel: ObservableObject {
    let record: HistoryRecord
    @Published var editingText: String

    init(record: HistoryRecord) {
        self.record = record
        self.editingText = record.refinedText
    }
}

struct CompareEditView: View {
    @StateObject private var model: CompareEditViewModel

    init(record: HistoryRecord) {
        _model = StateObject(wrappedValue: CompareEditViewModel(record: record))
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("原文")
                        .font(.headline)
                    Text(model.record.rawText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("润色")
                        .font(.headline)
                    Text(model.record.refinedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            TextEditor(text: $model.editingText)
                .frame(minHeight: 160)

            HStack {
                Spacer()
                Button("复制") {
                    PasteService.copyToClipboard(model.editingText)
                }
            }
        }
        .padding()
    }
}
