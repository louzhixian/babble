import AppKit
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
        print("ForceTouchTrigger: Starting with holdSeconds=\(holdSeconds), pressureThreshold=\(pressureThreshold)")

        // Create event tap for mouse events to capture pressure
        // We need to monitor mouse events because CGEvent tap doesn't directly
        // receive pressure events (type 34). The pressure value is available
        // when converting mouse events to NSEvent.
        let eventMask: CGEventMask =
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.leftMouseUp.rawValue) |
            (1 << CGEventType.leftMouseDragged.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.otherMouseUp.rawValue) |
            (1 << CGEventType.otherMouseDragged.rawValue) |
            // NSEventTypePressure = 34 (included for completeness, though CGEvent tap may not receive it)
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

        print("ForceTouchTrigger: Event tap created successfully")
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        print("ForceTouchTrigger: Started successfully")
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

        // Convert to NSEvent to read pressure
        if let nsEvent = NSEvent(cgEvent: event) {
            // Only process pressure events (type 34) - ignore mouse events
            // This filters out three-finger drag which simulates mouse events
            // Force Touch generates NSEventTypePressure (34) events
            if nsEvent.type == .pressure {
                let pressure = Double(nsEvent.pressure)
                print("ForceTouchTrigger: Received pressure event, pressure=\(pressure), eventType=\(nsEvent.type.rawValue)")
                Task { @MainActor in
                    sharedInstance?.handlePressure(pressure)
                }
            }
        }

        // Use passUnretained to avoid memory leak - we're just passing through the existing event
        return Unmanaged.passUnretained(event)
    }

    private func handlePressure(_ pressure: Double) {
        let isPressed = pressure >= pressureThreshold
        print("ForceTouchTrigger: handlePressure pressure=\(pressure), isPressed=\(isPressed), state=\(state)")

        switch state {
        case .idle:
            if isPressed {
                print("ForceTouchTrigger: Transitioning from idle to pressing")
                state = .pressing
                startHoldTimer()
            }

        case .pressing:
            if !isPressed {
                // Pressure released before threshold time
                print("ForceTouchTrigger: Pressure released before hold time, returning to idle")
                holdTimer?.invalidate()
                holdTimer = nil
                state = .idle
            }

        case .triggered:
            if !isPressed {
                print("ForceTouchTrigger: Pressure released after trigger, calling onTriggerEnd")
                state = .idle
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
        print("ForceTouchTrigger: Hold timer fired, triggering recording")
        onTriggerStart()
    }

#if DEBUG
    func setStateForTesting(_ state: TriggerState) {
        self.state = state
    }
#endif
}
