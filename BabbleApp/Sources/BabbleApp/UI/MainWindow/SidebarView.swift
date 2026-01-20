import SwiftUI

struct SidebarView: View {
    @Binding var selection: MainWindowRoute

    var body: some View {
        List(selection: $selection) {
            Text("History").tag(MainWindowRoute.history)
            Text("Compare/Edit").tag(MainWindowRoute.compareEdit)
            Text("Settings").tag(MainWindowRoute.settings)
        }
        .listStyle(.sidebar)
    }
}
