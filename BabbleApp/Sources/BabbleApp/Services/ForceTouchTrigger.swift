import AppKit

@MainActor
final class ForceTouchTrigger {
    enum TriggerState {
        case idle
        case pressing
        case triggered
    }

    private let holdSeconds: TimeInterval
    private let pressureThreshold: Float
    private let onTriggerStart: () -> Void
    private let onTriggerEnd: () -> Void
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var holdTimer: Timer?
    private var state: TriggerState = .idle

    init(
        holdSeconds: TimeInterval = 2.0,
        pressureThreshold: Float = 0.5,
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

        // Monitor pressure events from both local (in-app) and global (system-wide)
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.pressure]) { [weak self] event in
            Task { @MainActor in
                self?.handlePressureEvent(event)
            }
            return event
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.pressure]) { [weak self] event in
            Task { @MainActor in
                self?.handlePressureEvent(event)
            }
        }
    }

    func stop() {
        holdTimer?.invalidate()
        holdTimer = nil

        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        localMonitor = nil
        globalMonitor = nil

        if case .triggered = state {
            onTriggerEnd()
        }
        state = .idle
    }

    private func handlePressureEvent(_ event: NSEvent) {
        let pressure = event.pressure
        let isPressed = pressure >= pressureThreshold

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
