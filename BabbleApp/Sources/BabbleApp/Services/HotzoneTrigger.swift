import AppKit
import CoreGraphics

struct HotzoneDetector {
    let corner: HotzoneCorner
    let inset: CGFloat

    func isInside(point: CGPoint, in screen: CGRect) -> Bool {
        let zone: CGRect
        switch corner {
        case .bottomLeft:
            zone = CGRect(x: screen.minX, y: screen.minY, width: inset, height: inset)
        case .bottomRight:
            zone = CGRect(x: screen.maxX - inset, y: screen.minY, width: inset, height: inset)
        case .topLeft:
            zone = CGRect(x: screen.minX, y: screen.maxY - inset, width: inset, height: inset)
        case .topRight:
            zone = CGRect(x: screen.maxX - inset, y: screen.maxY - inset, width: inset, height: inset)
        }
        return zone.contains(point)
    }
}

@MainActor
final class HotzoneTrigger {
    enum TriggerState {
        case idle
        case hovering(Date)
        case triggered
    }

    private let holdSeconds: TimeInterval
    private let detector: HotzoneDetector
    private let onTrigger: () -> Void
    private var timer: Timer?
    private var state: TriggerState = .idle

    init(corner: HotzoneCorner, inset: CGFloat = 32, holdSeconds: TimeInterval, onTrigger: @escaping () -> Void) {
        self.detector = HotzoneDetector(corner: corner, inset: inset)
        self.holdSeconds = holdSeconds
        self.onTrigger = onTrigger
    }

    func start() {
        stop()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        state = .idle
    }

    private func tick() {
        guard let screen = NSScreen.main?.frame,
              let point = NSEvent.mouseLocation as CGPoint? else {
            state = .idle
            return
        }

        let inside = detector.isInside(point: point, in: screen)
        switch state {
        case .idle:
            if inside {
                state = .hovering(Date())
            }
        case .hovering(let start):
            if !inside {
                state = .idle
                return
            }
            if Date().timeIntervalSince(start) >= holdSeconds {
                state = .triggered
                onTrigger()
            }
        case .triggered:
            if !inside {
                state = .idle
            }
        }
    }
}
