// BabbleApp/Sources/BabbleApp/Services/PasteService.swift

import AppKit
import Carbon.HIToolbox

enum PasteError: Error, LocalizedError {
    case accessibilityNotGranted
    case pasteFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is required to simulate paste"
        case .pasteFailed:
            return "Failed to simulate paste keystroke"
        }
    }
}

struct PasteService {
    /// Copy text to clipboard and simulate Cmd+V paste
    static func pasteText(_ text: String) throws {
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        try simulatePaste()
    }

    /// Copy text to clipboard only (no paste simulation)
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func simulatePaste() throws {
        // Check accessibility permission
        // Using string literal to avoid concurrency issues with kAXTrustedCheckOptionPrompt
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": false]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            throw PasteError.accessibilityNotGranted
        }

        // Create Cmd+V key event
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) else {
            throw PasteError.pasteFailed
        }
        keyDown.flags = .maskCommand

        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            throw PasteError.pasteFailed
        }
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Check if accessibility permission is granted
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        // Using string literal to avoid concurrency issues with kAXTrustedCheckOptionPrompt
        let options: [String: Bool] = ["AXTrustedCheckOptionPrompt": prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
