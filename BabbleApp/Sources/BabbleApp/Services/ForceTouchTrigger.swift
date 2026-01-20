import AppKit
import ApplicationServices
import CoreGraphics

@MainActor
final class ForceTouchTrigger {
    enum TriggerState {
        case idle
        case pressing
        case triggered
    }

    private let holdSeconds: TimeInterval
    private let pressureThreshold: Double
    private let onTriggerStart: () -> Void
    private let onTriggerEnd: () -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var holdTimer: Timer?
    private var state: TriggerState = .idle

    // For filtering out three-finger drag by detecting mouse movement
    private var initialMouseLocation: CGPoint?
    private let movementThreshold: CGFloat = 5.0  // pixels - if mouse moves more than this, cancel

    // Static reference for C callback
    private nonisolated(unsafe) static var sharedInstance: ForceTouchTrigger?

    init(
        holdSeconds: TimeInterval = 2.0,
        pressureThreshold: Double = 0.5,
        onTriggerStart: @escaping () -> Void,
        onTriggerEnd: @escaping () -> Void
    ) {
        self.holdSeconds = holdSeconds
        self.pressureThreshold = pressureThreshold
        self.onTriggerStart = onTriggerStart
        self.onTriggerEnd = onTriggerEnd
    }

    func start() {
        stop()
        ForceTouchTrigger.sharedInstance = self

        // Check Accessibility permission
        let trusted = AXIsProcessTrusted()
        if !trusted {
            // Prompt user to grant permission
            let options: [String: Any] = ["AXTrustedCheckOptionPrompt": true]
            AXIsProcessTrustedWithOptions(options as CFDictionary)
            return
        }

        // Create event tap for all mouse events to capture pressure
        // CGEventMaskBit for pressure events is not directly available,
        // so we monitor mouse events and check pressure via NSEvent
        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            // NSEventTypePressure = 34
            (1 << 34)

        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,  // Don't block events, just observe
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return ForceTouchTrigger.handleEventTapCallback(proxy: proxy, type: type, event: event, refcon: refcon)
            },
            userInfo: nil
        )

        guard let eventTap = eventTap else {
            print("ForceTouchTrigger: Failed to create event tap. Check Accessibility permissions.")
            return
        }

        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    func stop() {
        holdTimer?.invalidate()
        holdTimer = nil

        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        ForceTouchTrigger.sharedInstance = nil
        initialMouseLocation = nil

        if case .triggered = state {
            onTriggerEnd()
        }
        state = .idle
    }

    private static func handleEventTapCallback(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent,
        refcon: UnsafeMutableRawPointer?
    ) -> Unmanaged<CGEvent>? {
        // Handle tap disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = sharedInstance?.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        // Get mouse location for movement detection
        let mouseLocation = event.location

        // Convert to NSEvent to read pressure
        if let nsEvent = NSEvent(cgEvent: event) {
            let pressure = Double(nsEvent.pressure)
            Task { @MainActor in
                sharedInstance?.handlePressureWithLocation(pressure, location: mouseLocation)
            }
        }

        // Use passUnretained to avoid memory leak - we're just passing through the existing event
        return Unmanaged.passUnretained(event)
    }

    private func handlePressureWithLocation(_ pressure: Double, location: CGPoint) {
        let isPressed = pressure >= pressureThreshold

        // Check for mouse movement when pressing (to filter out three-finger drag)
        if case .pressing = state, let initial = initialMouseLocation {
            let dx = abs(location.x - initial.x)
            let dy = abs(location.y - initial.y)
            if dx > movementThreshold || dy > movementThreshold {
                // Mouse moved - this is likely three-finger drag, not Force Touch
                holdTimer?.invalidate()
                holdTimer = nil
                state = .idle
                initialMouseLocation = nil
                return
            }
        }

        switch state {
        case .idle:
            if isPressed {
                state = .pressing
                initialMouseLocation = location
                startHoldTimer()
            }

        case .pressing:
            if !isPressed {
                // Pressure released before threshold time
                holdTimer?.invalidate()
                holdTimer = nil
                state = .idle
                initialMouseLocation = nil
            }

        case .triggered:
            if !isPressed {
                state = .idle
                initialMouseLocation = nil
                onTriggerEnd()
            }
        }
    }

    private func startHoldTimer() {
        holdTimer?.invalidate()
        holdTimer = Timer.scheduledTimer(withTimeInterval: holdSeconds, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.handleHoldTimerFired()
            }
        }
    }

    private func handleHoldTimerFired() {
        guard case .pressing = state else { return }
        state = .triggered
        onTriggerStart()
    }

#if DEBUG
    func setStateForTesting(_ state: TriggerState) {
        self.state = state
    }
#endif
}
