// BabbleApp/Sources/BabbleApp/Services/HotkeyManager.swift

import AppKit
import Carbon.HIToolbox

enum HotkeySource: Sendable {
    case keyboard
    case hotzone
    case forceTouch
}

enum HotkeyEvent: Sendable {
    case shortPress    // Toggle mode: tap to start/stop
    case longPressStart(HotkeySource)  // Push-to-talk: held down
    case longPressEnd(HotkeySource)    // Push-to-talk: released
    case cancelRecording  // ESC key pressed - cancel current recording
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
    private var forceTouchTrigger: ForceTouchTrigger?
    private var hotzoneHandler: HotkeyHandler?

    // Long press threshold in seconds
    private let longPressThreshold: TimeInterval = 0.3

    // Configurable hotkey (default: Option + Space)
    private var hotkeyKeyCode: CGKeyCode = CGKeyCode(kVK_Space)
    private var hotkeyModifiers: UInt64 = 0x80000  // Option key

    // ESC key for canceling recording
    private let escapeKeyCode: CGKeyCode = CGKeyCode(kVK_Escape)

    // Static callback context - nonisolated for C callback access
    private nonisolated(unsafe) static var sharedInstance: HotkeyManager?
    // Static hotkey config for callback access (since callback is nonisolated)
    private nonisolated(unsafe) static var currentHotkeyKeyCode: CGKeyCode = CGKeyCode(kVK_Space)
    private nonisolated(unsafe) static var currentHotkeyModifiers: UInt64 = 0x80000

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
            Log.hotkey.error("Failed to create event tap. Make sure Accessibility permission is granted.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func unregister() {
        hotzoneTrigger?.stop()
        hotzoneTrigger = nil
        forceTouchTrigger?.stop()
        forceTouchTrigger = nil
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

        hotzoneTrigger = HotzoneTrigger(
            corner: corner,
            holdSeconds: holdSeconds,
            onTriggerStart: { [weak self] in
                guard let self, let handler = self.hotzoneHandler else { return }
                handler(.longPressStart(.hotzone))
            },
            onTriggerEnd: { [weak self] in
                guard let self, let handler = self.hotzoneHandler else { return }
                handler(.longPressEnd(.hotzone))
            }
        )
        hotzoneTrigger?.start()
    }

    func configureForceTouch(enabled: Bool, holdSeconds: TimeInterval) {
        forceTouchTrigger?.stop()
        forceTouchTrigger = nil

        guard enabled else { return }

        forceTouchTrigger = ForceTouchTrigger(
            holdSeconds: holdSeconds,
            onTriggerStart: { [weak self] in
                guard let self, let handler = self.hotzoneHandler else { return }
                handler(.longPressStart(.forceTouch))
            },
            onTriggerEnd: { [weak self] in
                guard let self, let handler = self.hotzoneHandler else { return }
                handler(.longPressEnd(.forceTouch))
            }
        )
        forceTouchTrigger?.start()
    }

    func configureHotkey(keyCode: UInt16, modifiers: UInt64) {
        hotkeyKeyCode = CGKeyCode(keyCode)
        hotkeyModifiers = modifiers
        // Update static variables for callback access
        HotkeyManager.currentHotkeyKeyCode = CGKeyCode(keyCode)
        HotkeyManager.currentHotkeyModifiers = modifiers
    }

    /// Check if the event flags contain the required modifiers
    private static func checkModifiers(flags: CGEventFlags, required: UInt64) -> Bool {
        // Map our stored modifier values to CGEventFlags
        // Control: 0x40000, Option: 0x80000, Shift: 0x20000, Command: 0x100000
        var hasAllRequired = true

        if required & 0x40000 != 0 {  // Control
            hasAllRequired = hasAllRequired && flags.contains(.maskControl)
        }
        if required & 0x80000 != 0 {  // Option
            hasAllRequired = hasAllRequired && flags.contains(.maskAlternate)
        }
        if required & 0x20000 != 0 {  // Shift
            hasAllRequired = hasAllRequired && flags.contains(.maskShift)
        }
        if required & 0x100000 != 0 {  // Command
            hasAllRequired = hasAllRequired && flags.contains(.maskCommand)
        }

        return hasAllRequired
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

        // Check for ESC key to cancel recording
        if type == .keyDown && keyCode == instance.escapeKeyCode {
            Task { @MainActor in
                instance.handler?(.cancelRecording)
            }
            // Pass through ESC to other apps (don't suppress)
            return Unmanaged.passRetained(event)
        }

        // Check if this is our hotkey
        // For keyDown: require configured key + modifiers
        // For keyUp: if we're tracking a press (isKeyDown), accept key release even without modifiers
        //           (user may release modifier before key, which is common)
        let configuredKeyCode = currentHotkeyKeyCode
        let configuredModifiers = currentHotkeyModifiers

        // Check if required modifiers are pressed
        let hasRequiredModifiers = checkModifiers(flags: flags, required: configuredModifiers)

        let isKeyDownHotkey = type == .keyDown &&
            keyCode == configuredKeyCode &&
            hasRequiredModifiers
        let isKeyUpHotkey = type == .keyUp &&
            keyCode == configuredKeyCode &&
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
                handler?(.longPressEnd(.keyboard))
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
        handler?(.longPressStart(.keyboard))
    }
}
