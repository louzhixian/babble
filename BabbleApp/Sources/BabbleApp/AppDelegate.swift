// BabbleApp/Sources/BabbleApp/AppDelegate.swift

import AppKit
import AVFoundation
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanelWindow?
    private let controller = VoiceInputController()
    private let settingsStore = SettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupFloatingPanel()
        checkPermissions()
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Babble")
        }

        let actions = MenuActions(
            target: self,
            setRefineOff: #selector(setRefineOff(_:)),
            toggleRefineOption: #selector(toggleRefineOption(_:)),
            setPanelPosition: #selector(setPanelPosition(_:)),
            quit: #selector(quit)
        )
        statusItem?.menu = MenuBuilder().makeMenu(
            controller: controller,
            settingsStore: settingsStore,
            actions: actions
        )
    }

    private func setupFloatingPanel() {
        floatingPanel = FloatingPanelWindow(controller: controller)
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
        controller.refineOptions = []
        if let menu = sender.menu {
            updateRefineMenuState(menu)
        }
    }

    @objc private func toggleRefineOption(_ sender: NSMenuItem) {
        guard let option = sender.representedObject as? RefineOption else { return }
        if controller.refineOptions.contains(option) {
            controller.refineOptions.remove(option)
        } else {
            controller.refineOptions.insert(option)
        }

        if let menu = sender.menu {
            updateRefineMenuState(menu)
        }
    }

    private func updateRefineMenuState(_ menu: NSMenu) {
        for item in menu.items {
            if let option = item.representedObject as? RefineOption {
                item.state = controller.refineOptions.contains(option) ? .on : .off
            } else if let token = item.representedObject as? String, token == "off" {
                item.state = controller.refineOptions.isEmpty ? .on : .off
            }
        }
    }

    @objc private func setPanelPosition(_ sender: NSMenuItem) {
        guard let position = sender.representedObject as? FloatingPanelPosition else { return }
        settingsStore.floatingPanelPosition = position
        if let menu = sender.menu {
            updatePanelPositionMenuState(menu)
        }
        floatingPanel?.updatePosition()
    }

    private func updatePanelPositionMenuState(_ menu: NSMenu) {
        for item in menu.items {
            guard let position = item.representedObject as? FloatingPanelPosition else { continue }
            item.state = settingsStore.floatingPanelPosition == position ? .on : .off
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
