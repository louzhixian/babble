import AppKit
import CoreGraphics

// MARK: - MultitouchSupport Framework Bindings (Private API)

// Touch state values from MultitouchSupport
private let MTTouchStateTouching: Int32 = 4

// MTDevice opaque type
private typealias MTDeviceRef = UnsafeMutableRawPointer

// Callback type for contact frame - uses raw pointer for touch data
private typealias MTContactFrameCallback = @convention(c) (
    MTDeviceRef,
    UnsafeMutableRawPointer,  // Touch data pointer
    Int32,
    Double,
    Int32
) -> Int32

// MultitouchSupport framework function declarations
@_silgen_name("MTDeviceCreateDefault")
private func MTDeviceCreateDefault() -> MTDeviceRef?

@_silgen_name("MTRegisterContactFrameCallback")
private func MTRegisterContactFrameCallback(
    _ device: MTDeviceRef,
    _ callback: MTContactFrameCallback
) -> Void

@_silgen_name("MTUnregisterContactFrameCallback")
private func MTUnregisterContactFrameCallback(
    _ device: MTDeviceRef,
    _ callback: MTContactFrameCallback
) -> Void

@_silgen_name("MTDeviceStart")
private func MTDeviceStart(_ device: MTDeviceRef, _ mode: Int32) -> Void

@_silgen_name("MTDeviceStop")
private func MTDeviceStop(_ device: MTDeviceRef) -> Void

// MARK: - TrackpadHotzoneTrigger

// Simplified touch info extracted from raw data
struct TrackpadTouchInfo {
    let state: Int32
    let normalizedX: Float
    let normalizedY: Float
}

/// Detects when a single finger touches and stays in a corner of the trackpad
/// Uses MultitouchSupport framework for normalized position (0,0 = bottom-left, 1,1 = top-right)
@MainActor
final class TrackpadHotzoneTrigger {
    enum TriggerState {
        case idle
        case hovering(Date)
        case triggered
    }

    private let corner: HotzoneCorner
    private let holdSeconds: TimeInterval
    private let cornerSize: Float  // Fraction of trackpad (0.0 to 1.0)
    private let onTriggerStart: () -> Void
    private let onTriggerEnd: () -> Void
    private var device: MTDeviceRef?
    private var state: TriggerState = .idle
    private var hoverStartTime: Date?

    // Static reference for C callback - fileprivate for callback access
    fileprivate nonisolated(unsafe) static var sharedInstance: TrackpadHotzoneTrigger?

    init(
        corner: HotzoneCorner,
        holdSeconds: TimeInterval = 2.0,
        cornerSize: Float = 0.2,
        onTriggerStart: @escaping () -> Void,
        onTriggerEnd: @escaping () -> Void
    ) {
        self.corner = corner
        self.holdSeconds = holdSeconds
        self.cornerSize = cornerSize
        self.onTriggerStart = onTriggerStart
        self.onTriggerEnd = onTriggerEnd
    }

    func start() {
        stop()
        TrackpadHotzoneTrigger.sharedInstance = self

        guard let dev = MTDeviceCreateDefault() else {
            print("TrackpadHotzoneTrigger: Failed to create multitouch device")
            return
        }

        device = dev
        MTRegisterContactFrameCallback(dev, trackpadCallback)
        MTDeviceStart(dev, 0)
    }

    func stop() {
        if let dev = device {
            MTDeviceStop(dev)
            MTUnregisterContactFrameCallback(dev, trackpadCallback)
        }
        device = nil

        if case .triggered = state {
            onTriggerEnd()
        }
        state = .idle
        hoverStartTime = nil
        TrackpadHotzoneTrigger.sharedInstance = nil
    }

    fileprivate func handleTouches(_ touches: [TrackpadTouchInfo]) {
        // Filter to only touching fingers
        let activeTouches = touches.filter { $0.state == MTTouchStateTouching }

        if activeTouches.count == 1, let touch = activeTouches.first {
            handleSingleTouch(touch)
        } else if activeTouches.isEmpty {
            handleTouchEnded()
        } else {
            // Multiple fingers - cancel any pending trigger
            cancelHover()
        }
    }

    private func handleSingleTouch(_ touch: TrackpadTouchInfo) {
        let x = touch.normalizedX
        let y = touch.normalizedY

        // Check if touch is in the target corner
        let isInCorner = isPositionInCorner(x: x, y: y)

        switch state {
        case .idle:
            if isInCorner {
                state = .hovering(Date())
                hoverStartTime = Date()
            }

        case .hovering(let start):
            if !isInCorner {
                state = .idle
                hoverStartTime = nil
                return
            }
            if Date().timeIntervalSince(start) >= holdSeconds {
                state = .triggered
                onTriggerStart()
            }

        case .triggered:
            if !isInCorner {
                state = .idle
                hoverStartTime = nil
                onTriggerEnd()
            }
        }
    }

    private func handleTouchEnded() {
        if case .triggered = state {
            onTriggerEnd()
        }
        state = .idle
        hoverStartTime = nil
    }

    private func cancelHover() {
        if case .hovering = state {
            state = .idle
            hoverStartTime = nil
        }
        // Don't cancel if already triggered - wait for all fingers to lift
    }

    private func isPositionInCorner(x: Float, y: Float) -> Bool {
        // Normalized position: (0,0) = bottom-left, (1,1) = top-right
        switch corner {
        case .bottomLeft:
            return x < cornerSize && y < cornerSize
        case .bottomRight:
            return x > (1.0 - cornerSize) && y < cornerSize
        case .topLeft:
            return x < cornerSize && y > (1.0 - cornerSize)
        case .topRight:
            return x > (1.0 - cornerSize) && y > (1.0 - cornerSize)
        }
    }

#if DEBUG
    func setStateForTesting(_ state: TriggerState) {
        self.state = state
    }
#endif
}

// C callback function - must be at file scope
// MTTouch structure layout (based on MultitouchSupport):
// Offset  0: Int32 frame
// Offset  4: Double timestamp
// Offset 12: Int32 identifier
// Offset 16: Int32 state
// Offset 20: Int32 fingerID
// Offset 24: Int32 handID
// Offset 28: Float normalized.pos.x
// Offset 32: Float normalized.pos.y
// Offset 36: Float normalized.vel.x
// Offset 40: Float normalized.vel.y
// ... (more fields follow)
// Total size: approximately 80+ bytes per touch
private let kMTTouchSize = 80  // Conservative estimate

private func trackpadCallback(
    device: MTDeviceRef,
    data: UnsafeMutableRawPointer,
    nFingers: Int32,
    timestamp: Double,
    frame: Int32
) -> Int32 {
    var touches: [TrackpadTouchInfo] = []

    for i in 0..<Int(nFingers) {
        let touchPtr = data.advanced(by: i * kMTTouchSize)

        // Read state at offset 16
        let state = touchPtr.load(fromByteOffset: 16, as: Int32.self)

        // Read normalized position at offset 28 and 32
        let normalizedX = touchPtr.load(fromByteOffset: 28, as: Float.self)
        let normalizedY = touchPtr.load(fromByteOffset: 32, as: Float.self)

        touches.append(TrackpadTouchInfo(
            state: state,
            normalizedX: normalizedX,
            normalizedY: normalizedY
        ))
    }

    Task { @MainActor in
        TrackpadHotzoneTrigger.sharedInstance?.handleTouches(touches)
    }
    return 0
}
