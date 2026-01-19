// BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelWindow.swift

import AppKit
import SwiftUI

class FloatingPanelWindow: NSPanel {
    init(controller: VoiceInputController) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.maxY - frame.height - 50
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        contentView = NSHostingView(rootView: FloatingPanelView(controller: controller))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
