import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    @ObservedObject var settingsStore: SettingsStore

    var body: some View {
        List {
            ForEach(store.records) { record in
                HistoryRowView(
                    record: record,
                    historyStore: store,
                    playSoundOnCopy: settingsStore.playSoundOnCopy,
                    clearClipboardAfterCopy: settingsStore.clearClipboardAfterCopy
                )
            }
        }
    }
}
