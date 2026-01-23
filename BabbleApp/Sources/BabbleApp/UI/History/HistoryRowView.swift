import AppKit
import SwiftUI

enum HistoryTextVariant: String, CaseIterable, Hashable {
    case raw
    case refined

    func displayName(for language: AppLanguage) -> String {
        let l = L10n.strings(for: language)
        switch self {
        case .raw: return l.rawText
        case .refined: return l.refinedText
        }
    }
}

@MainActor
final class HistoryRowViewModel: ObservableObject {
    @Published var selectedVariant: HistoryTextVariant = .raw {
        didSet {
            guard isEditing else { return }
            editingText = selectedText
        }
    }
    @Published var editingText = ""
    @Published var isEditing = false

    private(set) var record: HistoryRecord

    init(record: HistoryRecord) {
        self.record = record
    }

    var selectedText: String {
        switch selectedVariant {
        case .raw:
            if record.editedVariant == .raw {
                return record.editedText ?? record.rawText
            }
            return record.rawText
        case .refined:
            if record.editedVariant == .refined {
                return record.editedText ?? record.refinedText
            }
            return record.refinedText
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
    private let clearClipboardAfterCopy: Bool
    @ObservedObject private var historyStore: HistoryStore
    let settingsStore: SettingsStore

    private var l: LocalizedStrings {
        L10n.strings(for: settingsStore.appLanguage)
    }

    init(record: HistoryRecord, historyStore: HistoryStore, settingsStore: SettingsStore, clearClipboardAfterCopy: Bool) {
        self.record = record
        _model = StateObject(wrappedValue: HistoryRowViewModel(record: record))
        _historyStore = ObservedObject(wrappedValue: historyStore)
        self.settingsStore = settingsStore
        self.clearClipboardAfterCopy = clearClipboardAfterCopy
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $model.selectedVariant) {
                    ForEach(HistoryTextVariant.allCases, id: \.self) { variant in
                        Text(variant.displayName(for: settingsStore.appLanguage)).tag(variant)
                    }
                }
                .pickerStyle(.segmented)

                Spacer()

                Button(l.edit) {
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
                Button(l.copy) {
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

        if clearClipboardAfterCopy {
            let pasteboard = NSPasteboard.general
            let expectedChangeCount = pasteboard.changeCount
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let currentText = pasteboard.string(forType: .string)
                if ClipboardClearGuard.shouldClear(
                    currentChangeCount: pasteboard.changeCount,
                    currentText: currentText,
                    expectedChangeCount: expectedChangeCount,
                    expectedText: text
                ) {
                    pasteboard.clearContents()
                }
            }
        }

        if model.isEditing {
            if let updated = historyStore.updateEditedText(
                for: model.record.id,
                editedText: model.editingText,
                editedVariant: model.selectedVariant
            ) {
                model.update(record: updated)
            }
            model.finishEditing()
        }
    }
}

struct ClipboardClearGuard {
    static func shouldClear(
        currentChangeCount: Int,
        currentText: String?,
        expectedChangeCount: Int,
        expectedText: String
    ) -> Bool {
        currentChangeCount == expectedChangeCount && currentText == expectedText
    }
}
