import AppKit

struct MenuActions {
    let target: AnyObject?
    let showMainWindow: Selector?
    let setRefineOff: Selector?
    let toggleRefineOption: Selector?
    let setPanelPosition: Selector?
    let quit: Selector?

    init(
        target: AnyObject? = nil,
        showMainWindow: Selector? = nil,
        setRefineOff: Selector? = nil,
        toggleRefineOption: Selector? = nil,
        setPanelPosition: Selector? = nil,
        quit: Selector? = nil
    ) {
        self.target = target
        self.showMainWindow = showMainWindow
        self.setRefineOff = setRefineOff
        self.toggleRefineOption = toggleRefineOption
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
        let menu = NSMenu()

        let mainWindowItem = NSMenuItem(title: "Main Window", action: actions.showMainWindow, keyEquivalent: "m")
        mainWindowItem.target = actions.target
        menu.addItem(mainWindowItem)

        menu.addItem(NSMenuItem.separator())

        // Refine options submenu
        let refineOptionsItem = NSMenuItem(title: "Refine Options", action: nil, keyEquivalent: "")
        let refineOptionsMenu = NSMenu()

        let options = settingsStore.defaultRefineOptions

        let offItem = NSMenuItem(title: "关闭", action: actions.setRefineOff, keyEquivalent: "")
        offItem.representedObject = "off"
        offItem.target = actions.target
        offItem.state = options.isEmpty ? .on : .off
        refineOptionsMenu.addItem(offItem)
        refineOptionsMenu.addItem(NSMenuItem.separator())

        for option in RefineOption.allCases {
            let item = NSMenuItem(title: option.rawValue, action: actions.toggleRefineOption, keyEquivalent: "")
            item.representedObject = option
            item.target = actions.target
            item.state = options.contains(option) ? .on : .off
            refineOptionsMenu.addItem(item)
        }

        refineOptionsItem.submenu = refineOptionsMenu
        menu.addItem(refineOptionsItem)

        menu.addItem(NSMenuItem.separator())

        // Floating panel position submenu
        let positionItem = NSMenuItem(title: "Panel Position", action: nil, keyEquivalent: "")
        let positionMenu = NSMenu()
        for position in FloatingPanelPosition.allCases {
            let item = NSMenuItem(title: position.displayName, action: actions.setPanelPosition, keyEquivalent: "")
            item.representedObject = position
            item.target = actions.target
            item.state = settingsStore.floatingPanelPosition == position ? .on : .off
            positionMenu.addItem(item)
        }
        positionItem.submenu = positionMenu
        menu.addItem(positionItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Babble", action: actions.quit, keyEquivalent: "q"))
        menu.items.last?.target = actions.target

        return menu
    }
}
