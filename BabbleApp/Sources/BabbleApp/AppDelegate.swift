// BabbleApp/Sources/BabbleApp/AppDelegate.swift

import AppKit
import AVFoundation
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanelWindow?
    private var mainWindow: NSWindow?
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupFloatingPanel()
        checkPermissions()
        coordinator.voiceInputController.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        coordinator.voiceInputController.stop()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Babble")
        }

        let actions = MenuActions(
            target: self,
            showMainWindow: #selector(showMainWindow),
            setRefineOff: #selector(setRefineOff(_:)),
            toggleRefineOption: #selector(toggleRefineOption(_:)),
            setPanelPosition: #selector(setPanelPosition(_:)),
            quit: #selector(quit)
        )
        statusItem?.menu = MenuBuilder().makeMenu(
            controller: coordinator.voiceInputController,
            settingsStore: coordinator.settingsStore,
            actions: actions
        )
    }

    private func setupFloatingPanel() {
        floatingPanel = FloatingPanelWindow(controller: coordinator.voiceInputController)
    }

    private func checkPermissions() {
        // Check microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.showPermissionAlert(for: "Microphone")
                }
            }
        }

        // Check accessibility permission
        if !PasteService.checkAccessibility(prompt: true) {
            showPermissionAlert(for: "Accessibility")
        }
    }

    private func showPermissionAlert(for permission: String) {
        let alert = NSAlert()
        alert.messageText = "\(permission) Permission Required"
        alert.informativeText = "Babble needs \(permission) permission to function. Please grant it in System Preferences."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if permission == "Microphone" {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            } else {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    @objc private func setRefineOff(_ sender: NSMenuItem) {
        coordinator.voiceInputController.refineOptions = []
        if let menu = sender.menu {
            updateRefineMenuState(menu)
        }
    }

    @objc private func toggleRefineOption(_ sender: NSMenuItem) {
        guard let option = sender.representedObject as? RefineOption else { return }
        if coordinator.voiceInputController.refineOptions.contains(option) {
            coordinator.voiceInputController.refineOptions.remove(option)
        } else {
            coordinator.voiceInputController.refineOptions.insert(option)
        }

        if let menu = sender.menu {
            updateRefineMenuState(menu)
        }
    }

    private func updateRefineMenuState(_ menu: NSMenu) {
        for item in menu.items {
            if let option = item.representedObject as? RefineOption {
                item.state = coordinator.voiceInputController.refineOptions.contains(option) ? .on : .off
            } else if let token = item.representedObject as? String, token == "off" {
                item.state = coordinator.voiceInputController.refineOptions.isEmpty ? .on : .off
            }
        }
    }

    @objc private func setPanelPosition(_ sender: NSMenuItem) {
        guard let position = sender.representedObject as? FloatingPanelPosition else { return }
        coordinator.settingsStore.floatingPanelPosition = position
        if let menu = sender.menu {
            updatePanelPositionMenuState(menu)
        }
        floatingPanel?.updatePosition()
    }

    private func updatePanelPositionMenuState(_ menu: NSMenu) {
        for item in menu.items {
            guard let position = item.representedObject as? FloatingPanelPosition else { continue }
            item.state = coordinator.settingsStore.floatingPanelPosition == position ? .on : .off
        }
    }

    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is FloatingPanelWindow) }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Babble"
            window.contentViewController = NSHostingController(
                rootView: MainWindowView(
                    historyStore: coordinator.historyStore,
                    settingsStore: coordinator.settingsStore,
                    router: coordinator.mainWindowRouter
                )
            )
            window.delegate = self
            window.center()
            window.makeKeyAndOrderFront(nil)
            mainWindow = window
        }
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if window == mainWindow {
            mainWindow = nil
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
