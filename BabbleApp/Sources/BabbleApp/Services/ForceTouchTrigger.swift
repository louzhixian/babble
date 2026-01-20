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
    private var pressureMonitor: Any?
    private var holdTimer: Timer?
    private var state: TriggerState = .idle

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

        print("ForceTouchTrigger: Starting with NSEvent.addGlobalMonitorForEvents")
        print("ForceTouchTrigger: holdSeconds=\(holdSeconds), pressureThreshold=\(pressureThreshold)")

        // Try monitoring multiple event types to see what we can receive
        let eventMask: NSEvent.EventTypeMask = [
            .pressure,
            .leftMouseDown,
            .leftMouseUp,
            .leftMouseDragged
        ]

        pressureMonitor = NSEvent.addGlobalMonitorForEvents(matching: eventMask) { [weak self] event in
            // Print all events we receive
            print("ForceTouchTrigger: Event received - type: \(event.type.rawValue) (\(event.type))")

            if event.type == .pressure {
                print("  PRESSURE EVENT: pressure=\(event.pressure), stage=\(event.stage)")
                Task { @MainActor in
                    self?.handlePressureEvent(event)
                }
            } else {
                // For mouse events, also check pressure value
                print("  Mouse event: pressure=\(event.pressure)")
            }
        }

        if pressureMonitor != nil {
            print("ForceTouchTrigger: Global monitor created successfully for: \(eventMask)")
        } else {
            print("ForceTouchTrigger: Failed to create monitor. Check Accessibility permissions.")
        }
    }

    func stop() {
        holdTimer?.invalidate()
        holdTimer = nil

        if let monitor = pressureMonitor {
            NSEvent.removeMonitor(monitor)
            pressureMonitor = nil
        }

        if case .triggered = state {
            onTriggerEnd()
        }
        state = .idle
    }

    private func handlePressureEvent(_ event: NSEvent) {
        let pressure = Double(event.pressure)
        let stage = event.stage

        print("ForceTouchTrigger: handlePressureEvent pressure=\(pressure), stage=\(stage), state=\(state)")

        // stage 1 = initial click, stage 2 = force click (deep press)
        // We trigger on sustained pressure above threshold
        let isPressed = pressure >= pressureThreshold

        handlePressure(isPressed)
    }

    private func handlePressure(_ isPressed: Bool) {
        switch state {
        case .idle:
            if isPressed {
                state = .pressing
                startHoldTimer()
            }

        case .pressing:
            if !isPressed {
                // Pressure released before threshold time
                holdTimer?.invalidate()
                holdTimer = nil
                state = .idle
            }

        case .triggered:
            if !isPressed {
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
        onTriggerStart()
    }

#if DEBUG
    func setStateForTesting(_ state: TriggerState) {
        self.state = state
    }
#endif
}
