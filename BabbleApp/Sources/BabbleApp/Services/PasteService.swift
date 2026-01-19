// BabbleApp/Sources/BabbleApp/Services/PasteService.swift

import AppKit
import Carbon.HIToolbox

protocol EventPoster {
    func postPaste() -> Bool
}

struct SystemEventPoster: EventPoster {
    func postPaste() -> Bool {
        // Create Cmd+V key event
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) else {
            return false
        }
        keyDown.flags = .maskCommand

        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            return false
        }
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

struct PasteService {
    private let eventPoster: EventPoster

    init(eventPoster: EventPoster = SystemEventPoster()) {
        self.eventPoster = eventPoster
    }

    /// Copy text to clipboard and simulate Cmd+V paste
    func pasteText(_ text: String) -> Bool {
        Self.copyToClipboard(text)
        return pasteFromClipboard()
    }

    /// Simulate Cmd+V paste from clipboard
    func pasteFromClipboard() -> Bool {
        // Check accessibility permission
        // Using string literal to avoid concurrency issues with kAXTrustedCheckOptionPrompt
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": false]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            return false
        }

        return eventPoster.postPaste()
    }

    /// Copy text to clipboard only (no paste simulation)
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Check if accessibility permission is granted
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        // Using string literal to avoid concurrency issues with kAXTrustedCheckOptionPrompt
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
