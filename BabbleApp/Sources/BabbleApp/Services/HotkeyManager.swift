// BabbleApp/Sources/BabbleApp/Services/HotkeyManager.swift

import AppKit
import Carbon.HIToolbox

enum HotkeyEvent {
    case shortPress    // Toggle mode: tap to start/stop
    case longPressStart  // Push-to-talk: held down
    case longPressEnd    // Push-to-talk: released
}

@MainActor
class HotkeyManager: ObservableObject {
    typealias HotkeyHandler = (HotkeyEvent) -> Void

    private var eventMonitor: Any?
    private var keyDownTime: Date?
    private var isKeyDown = false
    private var longPressTriggered = false
    private var longPressTimer: Timer?
    private var handler: HotkeyHandler?

    // Long press threshold in seconds
    private let longPressThreshold: TimeInterval = 0.3

    // Default hotkey: Option + Space
    private let hotkeyKeyCode: UInt16 = UInt16(kVK_Space)
    private let hotkeyModifiers: NSEvent.ModifierFlags = .option

    func register(handler: @escaping HotkeyHandler) {
        self.handler = handler

        // Monitor key events globally
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }
    }

    func unregister() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        handler = nil
    }

    private func handleEvent(_ event: NSEvent) {
        // Check if it's our hotkey
        guard event.keyCode == hotkeyKeyCode else { return }

        switch event.type {
        case .keyDown:
            guard !isKeyDown else { return } // Ignore key repeat
            guard event.modifierFlags.contains(hotkeyModifiers) else { return }

            isKeyDown = true
            longPressTriggered = false
            keyDownTime = Date()

            // Start timer to detect long press
            longPressTimer?.invalidate()
            longPressTimer = Timer.scheduledTimer(withTimeInterval: longPressThreshold, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.handleLongPressThreshold()
                }
            }

        case .keyUp:
            guard isKeyDown else { return }
            isKeyDown = false
            longPressTimer?.invalidate()
            longPressTimer = nil

            if longPressTriggered {
                // Long press released
                handler?(.longPressEnd)
            } else {
                // Short press - toggle mode
                handler?(.shortPress)
            }

            keyDownTime = nil
            longPressTriggered = false

        default:
            break
        }
    }

    private func handleLongPressThreshold() {
        guard isKeyDown else { return }
        longPressTriggered = true
        handler?(.longPressStart)
    }
}
