// BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelWindow.swift

import AppKit
import Combine
import SwiftUI

class FloatingPanelWindow: NSPanel {
    private let controller: VoiceInputController
    private let layout = FloatingPanelLayout(margin: 20)
    private let settingsStore = SettingsStore()
    private var stateCancellable: AnyCancellable?

    init(controller: VoiceInputController) {
        self.controller = controller
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

        let hostingView = NSHostingView(rootView: FloatingPanelView(controller: controller))
        contentView = hostingView

        updateFrame()
        apply(state: controller.panelState)

        stateCancellable = controller.$panelState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.apply(state: state)
            }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func updatePosition() {
        updateFrame()
    }

    private func apply(state: FloatingPanelState) {
        switch state.status {
        case .idle:
            orderOut(nil)
        case .recording, .processing, .pasteFailed, .error:
            updateFrame()
            orderFrontRegardless()
        }
    }

    private func updateFrame() {
        guard let screen = NSScreen.main else { return }
        let panelSize = contentView?.fittingSize ?? frame.size
        let targetFrame = layout.frame(
            for: settingsStore.floatingPanelPosition,
            panelSize: panelSize,
            in: screen.visibleFrame
        )
        setFrame(targetFrame, display: true)
    }
}
