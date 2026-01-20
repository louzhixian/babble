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
        print("ForceTouchTrigger: Starting with holdSeconds=\(holdSeconds), pressureThreshold=\(pressureThreshold)")

        // Use NSEvent global monitor for pressure events
        // CGEvent tap doesn't receive NSEventTypePressure (type 34) events
        // NSEvent.addGlobalMonitorForEvents properly handles .pressure events from Force Touch trackpad
        pressureMonitor = NSEvent.addGlobalMonitorForEvents(matching: .pressure) { [weak self] event in
            let pressure = Double(event.pressure)
            print("ForceTouchTrigger: Received pressure event, pressure=\(pressure)")
            Task { @MainActor in
                self?.handlePressure(pressure)
            }
        }

        if pressureMonitor != nil {
            print("ForceTouchTrigger: Pressure monitor created successfully")
        } else {
            print("ForceTouchTrigger: Failed to create pressure monitor")
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
