// BabbleApp/Sources/BabbleApp/AppDelegate.swift

import AppKit
import AVFoundation
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanelWindow?
    private let controller = VoiceInputController()

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

        let menu = NSMenu()

        // Refine mode submenu
        let refineModeItem = NSMenuItem(title: "Refine Mode", action: nil, keyEquivalent: "")
        let refineModeMenu = NSMenu()
        for mode in RefineMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(setRefineMode(_:)), keyEquivalent: "")
            item.representedObject = mode
            item.state = controller.refineMode == mode ? .on : .off
            refineModeMenu.addItem(item)
        }
        refineModeItem.submenu = refineModeMenu
        menu.addItem(refineModeItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Show Panel", action: #selector(showPanel), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Hide Panel", action: #selector(hidePanel), keyEquivalent: "h"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Babble", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
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

    @objc private func setRefineMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? RefineMode else { return }
        controller.refineMode = mode

        // Update menu checkmarks
        if let menu = sender.menu {
            for item in menu.items {
                item.state = item.representedObject as? RefineMode == mode ? .on : .off
            }
        }
    }

    @objc private func showPanel() {
        floatingPanel?.orderFront(nil)
    }

    @objc private func hidePanel() {
        floatingPanel?.orderOut(nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
