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

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var keyDownTime: Date?
    private var isKeyDown = false
    private var longPressTriggered = false
    private var longPressTimer: Timer?
    private var handler: HotkeyHandler?
    private var hotzoneTrigger: HotzoneTrigger?
    private var hotzoneHandler: HotkeyHandler?

    // Long press threshold in seconds
    private let longPressThreshold: TimeInterval = 0.3

    // Default hotkey: Option + Space
    private let hotkeyKeyCode: CGKeyCode = CGKeyCode(kVK_Space)
    private let hotkeyModifierMask: CGEventFlags = .maskAlternate

    // Static callback context
    private static var sharedInstance: HotkeyManager?

    func register(handler: @escaping HotkeyHandler) {
        self.handler = handler
        self.hotzoneHandler = handler
        HotkeyManager.sharedInstance = self

        // Create event tap to intercept key events
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return HotkeyManager.handleEventTapCallback(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: nil
        )

        guard let eventTap = eventTap else {
            print("Failed to create event tap. Make sure Accessibility permission is granted.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func unregister() {
        hotzoneTrigger?.stop()
        hotzoneTrigger = nil
        hotzoneHandler = nil
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        handler = nil
        HotkeyManager.sharedInstance = nil
    }

    func configureHotzone(enabled: Bool, corner: HotzoneCorner, holdSeconds: TimeInterval) {
        hotzoneTrigger?.stop()
        hotzoneTrigger = nil

        guard enabled else { return }

        hotzoneTrigger = HotzoneTrigger(corner: corner, holdSeconds: holdSeconds) { [weak self] in
            guard let self, let handler = self.hotzoneHandler else { return }
            handler(.longPressStart)
            handler(.longPressEnd)
        }
        hotzoneTrigger?.start()
    }

    private static func handleEventTapCallback(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        // Handle tap disabled event (system may disable if events queue up)
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = sharedInstance?.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard let instance = sharedInstance else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        // Check if this is our hotkey
        // For keyDown: require Option + Space
        // For keyUp: if we're tracking a press (isKeyDown), accept Space release even without Option
        //           (user may release Option before Space, which is common)
        let isKeyDownHotkey = type == .keyDown &&
            keyCode == instance.hotkeyKeyCode &&
            flags.contains(instance.hotkeyModifierMask)
        let isKeyUpHotkey = type == .keyUp &&
            keyCode == instance.hotkeyKeyCode &&
            instance.isKeyDown

        if isKeyDownHotkey || isKeyUpHotkey {
            // Dispatch to main actor for state handling
            Task { @MainActor in
                instance.handleEvent(type: type)
            }
            // Return nil to suppress the event (don't pass to foreground app)
            return nil
        }

        // Pass through all other events
        return Unmanaged.passRetained(event)
    }

    private func handleEvent(type: CGEventType) {
        switch type {
        case .keyDown:
            guard !isKeyDown else { return } // Ignore key repeat

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
