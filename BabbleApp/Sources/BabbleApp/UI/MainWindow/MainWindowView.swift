import SwiftUI

enum MainWindowRoute: Hashable {
    case history
    case compareEdit
    case settings
}

@MainActor
final class MainWindowRouter: ObservableObject {
    @Published var selection: MainWindowRoute = .history
}

struct MainWindowView: View {
    @StateObject private var router: MainWindowRouter
    @ObservedObject var historyStore: HistoryStore
    let settingsStore: SettingsStore

    init(
        historyStore: HistoryStore = HistoryStore(limit: 100),
        settingsStore: SettingsStore = SettingsStore(),
        router: MainWindowRouter = MainWindowRouter()
    ) {
        _router = StateObject(wrappedValue: router)
        self.historyStore = historyStore
        self.settingsStore = settingsStore
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $router.selection)
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch router.selection {
        case .history:
            HistoryView(store: historyStore, settingsStore: settingsStore)
        case .compareEdit:
            if let record = historyStore.records.first {
                CompareEditView(record: record)
            } else {
                Text("暂无记录")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .settings:
            SettingsView(store: settingsStore)
        }
    }
}
