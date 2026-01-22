import AppKit
import SwiftUI

/// A view that captures keyboard shortcuts when clicked
struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkeyConfig: HotkeyConfig
    @Binding var isRecording: Bool

    func makeNSView(context: Context) -> HotkeyRecorderNSView {
        let view = HotkeyRecorderNSView()
        view.delegate = context.coordinator
        return view
    }

    func updateNSView(_ nsView: HotkeyRecorderNSView, context: Context) {
        nsView.isRecording = isRecording
        nsView.hotkeyConfig = hotkeyConfig
        nsView.needsDisplay = true
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor
    class Coordinator: NSObject, HotkeyRecorderDelegate {
        var parent: HotkeyRecorderView

        init(_ parent: HotkeyRecorderView) {
            self.parent = parent
        }

        func hotkeyRecorderDidStartRecording(_ recorder: HotkeyRecorderNSView) {
            parent.isRecording = true
        }

        func hotkeyRecorderDidCancelRecording(_ recorder: HotkeyRecorderNSView) {
            parent.isRecording = false
        }

        func hotkeyRecorder(_ recorder: HotkeyRecorderNSView, didRecordHotkey config: HotkeyConfig) {
            parent.hotkeyConfig = config
            parent.isRecording = false
        }
    }
}

@MainActor
protocol HotkeyRecorderDelegate: AnyObject {
    func hotkeyRecorderDidStartRecording(_ recorder: HotkeyRecorderNSView)
    func hotkeyRecorderDidCancelRecording(_ recorder: HotkeyRecorderNSView)
    func hotkeyRecorder(_ recorder: HotkeyRecorderNSView, didRecordHotkey config: HotkeyConfig)
}

class HotkeyRecorderNSView: NSView {
    weak var delegate: HotkeyRecorderDelegate?
    var isRecording = false {
        didSet { needsDisplay = true }
    }
    var hotkeyConfig: HotkeyConfig = .defaultConfig {
        didSet { needsDisplay = true }
    }

    private var trackingArea: NSTrackingArea?
    private var isHovered = false

    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        wantsLayer = true
        layer?.cornerRadius = 6
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow],
            owner: self,
            userInfo: nil
        )
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func mouseDown(with event: NSEvent) {
        if !isRecording {
            isRecording = true
            window?.makeFirstResponder(self)
            Task { @MainActor in
                delegate?.hotkeyRecorderDidStartRecording(self)
            }
        }
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let keyCode = event.keyCode
        let modifiers = event.modifierFlags.rawValue & 0x1F0000  // Keep only modifier bits

        // ESC cancels recording
        if keyCode == 53 {
            isRecording = false
            Task { @MainActor in
                delegate?.hotkeyRecorderDidCancelRecording(self)
            }
            return
        }

        // Require at least one modifier (except for function keys)
        let isFunctionKey = keyCode >= 96 && keyCode <= 122
        if modifiers == 0 && !isFunctionKey {
            // Flash or beep to indicate modifier is required
            NSSound.beep()
            return
        }

        let config = HotkeyConfig(keyCode: keyCode, modifiers: UInt64(modifiers))
        hotkeyConfig = config
        isRecording = false
        Task { @MainActor in
            delegate?.hotkeyRecorder(self, didRecordHotkey: config)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        // Just update display when modifiers change during recording
        if isRecording {
            needsDisplay = true
        }
    }

    override func resignFirstResponder() -> Bool {
        if isRecording {
            isRecording = false
            Task { @MainActor in
                delegate?.hotkeyRecorderDidCancelRecording(self)
            }
        }
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        let backgroundColor: NSColor
        let borderColor: NSColor

        if isRecording {
            backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.1)
            borderColor = NSColor.controlAccentColor
        } else if isHovered {
            backgroundColor = NSColor.controlBackgroundColor
            borderColor = NSColor.separatorColor
        } else {
            backgroundColor = NSColor.controlBackgroundColor
            borderColor = NSColor.separatorColor.withAlphaComponent(0.5)
        }

        // Draw background
        backgroundColor.setFill()
        let bgPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 5, yRadius: 5)
        bgPath.fill()

        // Draw border
        borderColor.setStroke()
        let borderPath = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 6, yRadius: 6)
        borderPath.lineWidth = 1
        borderPath.stroke()

        // Draw text
        let text: String
        let textColor: NSColor

        if isRecording {
            text = "按下快捷键..."
            textColor = NSColor.controlAccentColor
        } else {
            text = hotkeyConfig.displayString
            textColor = NSColor.labelColor
        }

        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: textColor
        ]
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let textSize = attributedString.size()
        let textRect = NSRect(
            x: (bounds.width - textSize.width) / 2,
            y: (bounds.height - textSize.height) / 2,
            width: textSize.width,
            height: textSize.height
        )
        attributedString.draw(in: textRect)
    }
}
