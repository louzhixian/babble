import SwiftUI

struct SidebarView: View {
    @Binding var selection: MainWindowRoute
    let settingsStore: SettingsStore

    private var l: LocalizedStrings {
        L10n.strings(for: settingsStore.appLanguage)
    }

    var body: some View {
        List(selection: $selection) {
            Text(l.settings).tag(MainWindowRoute.settings)
            Text(l.history).tag(MainWindowRoute.history)
        }
        .listStyle(.sidebar)
        .toolbar(removing: .sidebarToggle)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
                } label: {
                    Image(systemName: "sidebar.leading")
                }
            }
        }
    }
}
