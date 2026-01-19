import AppKit
import SwiftUI

enum HistoryTextVariant: String, CaseIterable, Hashable {
    case raw = "原文"
    case refined = "润色"
}

@MainActor
final class HistoryRowViewModel: ObservableObject {
    @Published var selectedVariant: HistoryTextVariant = .raw
    @Published var editingText = ""
    @Published var isEditing = false

    private(set) var record: HistoryRecord

    init(record: HistoryRecord) {
        self.record = record
    }

    var selectedText: String {
        switch selectedVariant {
        case .raw:
            return record.rawText
        case .refined:
            return record.editedText ?? record.refinedText
        }
    }

    func beginEditing() {
        editingText = selectedText
        isEditing = true
    }

    func finishEditing() {
        isEditing = false
    }

    func update(record: HistoryRecord) {
        self.record = record
    }
}

struct HistoryRowView: View {
    private let record: HistoryRecord
    @StateObject private var model: HistoryRowViewModel
    private let playSoundOnCopy: Bool
    private let clearClipboardAfterCopy: Bool
    @ObservedObject private var historyStore: HistoryStore

    init(record: HistoryRecord, historyStore: HistoryStore, playSoundOnCopy: Bool, clearClipboardAfterCopy: Bool) {
        self.record = record
        _model = StateObject(wrappedValue: HistoryRowViewModel(record: record))
        _historyStore = ObservedObject(wrappedValue: historyStore)
        self.playSoundOnCopy = playSoundOnCopy
        self.clearClipboardAfterCopy = clearClipboardAfterCopy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $model.selectedVariant) {
                    ForEach(HistoryTextVariant.allCases, id: \.self) { variant in
                        Text(variant.rawValue).tag(variant)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                Button("编辑") {
                    model.beginEditing()
                }
            }

            if model.isEditing {
                TextEditor(text: $model.editingText)
                    .frame(minHeight: 80)
            } else {
                Text(model.selectedText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            HStack {
                Spacer()
                Button("复制") {
                    copyCurrentText()
                }
            }
        }
        .padding(.vertical, 8)
        .onChange(of: record.id) { _, _ in
            model.update(record: record)
        }
    }

    private func copyCurrentText() {
        let text = model.isEditing ? model.editingText : model.selectedText
        PasteService.copyToClipboard(text)

        if playSoundOnCopy {
            NSSound.beep()
        }

        if clearClipboardAfterCopy {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                NSPasteboard.general.clearContents()
            }
        }

        if model.isEditing {
            if let updated = historyStore.updateEditedText(for: model.record.id, editedText: model.editingText) {
                model.update(record: updated)
            }
            model.finishEditing()
        }
    }
}
