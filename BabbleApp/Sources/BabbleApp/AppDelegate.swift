// BabbleApp/Sources/BabbleApp/AppDelegate.swift

import AppKit
import AVFoundation
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanelWindow?
    private var mainWindow: NSWindow?
    private var downloadWindow: NSWindow?
    let coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure app shows in Dock (Info.plist LSUIElement is ignored by swift run)
        NSApp.setActivationPolicy(.regular)

        if coordinator.downloadManager.isDownloadNeeded() {
            // First launch or missing files: show download window
            showDownloadWindow()
        } else {
            // Files exist: verify checksum before starting
            // This prevents using a corrupted binary
            Task {
                let isValid = await coordinator.downloadManager.verifyAndRepairInBackground()
                if isValid {
                    proceedWithNormalStartup()
                } else {
                    // Verification failed and repair needed - show download window
                    showDownloadWindow()
                }
            }
        }
    }

    private func proceedWithNormalStartup() {
        setupMenuBar()
        setupFloatingPanel()
        checkPermissions()
        coordinator.voiceInputController.start()
    }

    private func showDownloadWindow() {
        // Activate app first to ensure window will be visible
        NSApp.activate(ignoringOtherApps: true)

        let downloadView = DownloadView(downloadManager: coordinator.downloadManager) { [weak self] in
            self?.downloadWindow?.close()
            self?.downloadWindow = nil
            self?.proceedWithNormalStartup()
        }

        let hostingController = NSHostingController(rootView: downloadView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled],  // Not closable during download
            backing: .buffered,
            defer: false
        )
        window.title = "Babble Setup"
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.center()
        downloadWindow = window

        // Use orderFrontRegardless to ensure window appears even on fresh launch
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()

        // Start the download unconditionally (we already checked isDownloadNeeded)
        Task {
            await coordinator.downloadManager.startDownload()
        }
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
        floatingPanel = FloatingPanelWindow(
            controller: coordinator.voiceInputController,
            settingsStore: coordinator.settingsStore
        )
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

        // Check accessibility permission once at startup
        // This triggers the system prompt if not already granted
        if !AXIsProcessTrusted() {
            let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
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

        // Create main window lazily (kept alive for app lifetime)
        if mainWindow == nil {
            let contentView = MainWindowView(
                historyStore: coordinator.historyStore,
                settingsStore: coordinator.settingsStore,
                router: coordinator.mainWindowRouter
            )
            let hostingController = NSHostingController(rootView: contentView)

            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 720),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Babble"
            window.minSize = NSSize(width: 600, height: 400)
            window.contentViewController = hostingController
            window.isReleasedWhenClosed = false  // Keep window alive when closed
            window.center()
            window.delegate = self
            mainWindow = window
        }

        // Set floating level to ensure window appears on top
        mainWindow?.level = .floating
        mainWindow?.makeKeyAndOrderFront(nil)
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        // When window loses focus, reset to normal level so it doesn't always float
        if let window = notification.object as? NSWindow, window === mainWindow {
            window.level = .normal
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
