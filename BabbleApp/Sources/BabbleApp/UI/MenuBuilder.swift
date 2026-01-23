import AppKit

struct MenuActions {
    let target: AnyObject?
    let showMainWindow: Selector?
    let setPanelPosition: Selector?
    let quit: Selector?

    init(
        target: AnyObject? = nil,
        showMainWindow: Selector? = nil,
        setPanelPosition: Selector? = nil,
        quit: Selector? = nil
    ) {
        self.target = target
        self.showMainWindow = showMainWindow
        self.setPanelPosition = setPanelPosition
        self.quit = quit
    }
}

struct MenuBuilder {
    @MainActor
    func makeMenu(
        controller: VoiceInputController,
        settingsStore: SettingsStore,
        actions: MenuActions = MenuActions()
    ) -> NSMenu {
        let l = L10n.strings(for: settingsStore.appLanguage)
        let menu = NSMenu()

        let mainWindowItem = NSMenuItem(title: l.mainWindow, action: actions.showMainWindow, keyEquivalent: "m")
        mainWindowItem.target = actions.target
        menu.addItem(mainWindowItem)

        menu.addItem(NSMenuItem.separator())

        // Floating panel position submenu
        let positionItem = NSMenuItem(title: l.panelPosition, action: nil, keyEquivalent: "")
        let positionMenu = NSMenu()
        for position in FloatingPanelPosition.allCases {
            let item = NSMenuItem(title: position.displayName(for: settingsStore.appLanguage), action: actions.setPanelPosition, keyEquivalent: "")
            item.representedObject = position
            item.target = actions.target
            item.state = settingsStore.floatingPanelPosition == position ? .on : .off
            positionMenu.addItem(item)
        }
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: l.quitApp, action: actions.quit, keyEquivalent: "q"))
        menu.items.last?.target = actions.target

        return menu
    }
}
