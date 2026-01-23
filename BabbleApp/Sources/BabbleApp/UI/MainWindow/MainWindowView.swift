import SwiftUI

enum MainWindowRoute: Hashable {
    case history
    case settings
}

@MainActor
final class MainWindowRouter: ObservableObject {
    @Published var selection: MainWindowRoute = .settings
}

struct MainWindowView: View {
    @ObservedObject var router: MainWindowRouter
    @ObservedObject var historyStore: HistoryStore
    let settingsStore: SettingsStore

    init(
        historyStore: HistoryStore = HistoryStore(limit: 100),
        settingsStore: SettingsStore = SettingsStore(),
        router: MainWindowRouter = MainWindowRouter()
    ) {
        self.router = router
        self.historyStore = historyStore
        self.settingsStore = settingsStore
    }

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $router.selection, settingsStore: settingsStore)
        } detail: {
            detailView
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch router.selection {
        case .history:
            HistoryView(store: historyStore, settingsStore: settingsStore)
        case .settings:
            SettingsView(store: settingsStore)
        }
    }
}
