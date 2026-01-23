import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    private let defaults: UserDefaults
    private let positionKey = "floatingPanelPosition"
    private let historyLimitKey = "historyLimit"
    private let refineEnabledKey = "refineEnabled"
    private let refinePromptKey = "refinePrompt"
    private let defaultLanguageKey = "defaultLanguage"
    private let whisperPortKey = "whisperPort"
    private let clearClipboardAfterCopyKey = "clearClipboardAfterCopy"
    private let hotzoneEnabledKey = "hotzoneEnabled"
    private let hotzoneCornerKey = "hotzoneCorner"
    private let hotzoneHoldSecondsKey = "hotzoneHoldSeconds"
    private let forceTouchEnabledKey = "forceTouchEnabled"
    private let forceTouchHoldSecondsKey = "forceTouchHoldSeconds"
    private let hotkeyKeyCodeKey = "hotkeyKeyCode"
    private let hotkeyModifiersKey = "hotkeyModifiers"
    private let appLanguageKey = "appLanguage"

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    var floatingPanelPosition: FloatingPanelPosition {
        get {
            guard let raw = defaults.string(forKey: positionKey),
                  let value = FloatingPanelPosition(rawValue: raw) else {
                return .bottom
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: positionKey)
        }
    }

    var historyLimit: Int {
        get {
            let stored = defaults.integer(forKey: historyLimitKey)
            return stored > 0 ? stored : 100
        }
        set {
            defaults.set(newValue, forKey: historyLimitKey)
            NotificationCenter.default.post(
                name: .settingsHistoryLimitDidChange,
                object: self,
                userInfo: ["value": newValue]
            )
        }
    }

    var refineEnabled: Bool {
        get { defaults.object(forKey: refineEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: refineEnabledKey) }
    }

    var refinePrompt: String {
        get { defaults.string(forKey: refinePromptKey) ?? RefineService.defaultPrompt }
        set { defaults.set(newValue, forKey: refinePromptKey) }
    }

    var defaultLanguage: String {
        get { defaults.string(forKey: defaultLanguageKey) ?? "zh" }
        set { defaults.set(newValue, forKey: defaultLanguageKey) }
    }

    var whisperPort: Int {
        get {
            let stored = defaults.integer(forKey: whisperPortKey)
            return stored > 0 ? stored : 8787
        }
        set {
            defaults.set(newValue, forKey: whisperPortKey)
            NotificationCenter.default.post(name: .settingsWhisperPortDidChange, object: self)
        }
    }

    var clearClipboardAfterCopy: Bool {
        get { defaults.object(forKey: clearClipboardAfterCopyKey) as? Bool ?? false }
        set {
            objectWillChange.send()
            defaults.set(newValue, forKey: clearClipboardAfterCopyKey)
        }
    }

    var hotzoneEnabled: Bool {
        get { defaults.object(forKey: hotzoneEnabledKey) as? Bool ?? false }
        set {
            defaults.set(newValue, forKey: hotzoneEnabledKey)
            NotificationCenter.default.post(name: .settingsHotzoneDidChange, object: self)
        }
    }

    var hotzoneCorner: HotzoneCorner {
        get {
            guard let raw = defaults.string(forKey: hotzoneCornerKey),
                  let value = HotzoneCorner(rawValue: raw) else {
                return .bottomLeft
            }
            return value
        }
        set {
            defaults.set(newValue.rawValue, forKey: hotzoneCornerKey)
            NotificationCenter.default.post(name: .settingsHotzoneDidChange, object: self)
        }
    }

    var hotzoneHoldSeconds: Double {
        get {
            let stored = defaults.double(forKey: hotzoneHoldSecondsKey)
            return stored > 0 ? stored : 2.0
        }
        set {
            defaults.set(newValue, forKey: hotzoneHoldSecondsKey)
            NotificationCenter.default.post(name: .settingsHotzoneDidChange, object: self)
        }
    }

    var forceTouchEnabled: Bool {
        get { defaults.object(forKey: forceTouchEnabledKey) as? Bool ?? true }
        set {
            defaults.set(newValue, forKey: forceTouchEnabledKey)
            NotificationCenter.default.post(name: .settingsForceTouchDidChange, object: self)
        }
    }

    var forceTouchHoldSeconds: Double {
        get {
            let stored = defaults.double(forKey: forceTouchHoldSecondsKey)
            return stored > 0 ? stored : 1.5
        }
        set {
            defaults.set(newValue, forKey: forceTouchHoldSecondsKey)
            NotificationCenter.default.post(name: .settingsForceTouchDidChange, object: self)
        }
    }

    // Hotkey configuration
    // Default: Option + Space (keyCode 49 = Space, modifiers includes Option)
    var hotkeyKeyCode: UInt16 {
        get {
            // Use object(forKey:) to detect unset vs stored 0
            // keyCode 0 is valid (A key), so we can't use stored > 0
            if defaults.object(forKey: hotkeyKeyCodeKey) == nil {
                return 49  // Default to Space
            }
            return UInt16(defaults.integer(forKey: hotkeyKeyCodeKey))
        }
        set {
            defaults.set(Int(newValue), forKey: hotkeyKeyCodeKey)
            NotificationCenter.default.post(name: .settingsHotkeyDidChange, object: self)
        }
    }

    var hotkeyModifiers: UInt64 {
        get {
            // Default to Option key (0x80000 = NSEvent.ModifierFlags.option.rawValue)
            if defaults.object(forKey: hotkeyModifiersKey) == nil {
                return 0x80000  // Option key
            }
            return UInt64(defaults.integer(forKey: hotkeyModifiersKey))
        }
        set {
            defaults.set(Int(newValue), forKey: hotkeyModifiersKey)
            NotificationCenter.default.post(name: .settingsHotkeyDidChange, object: self)
        }
    }

    var hotkeyConfig: HotkeyConfig {
        get { HotkeyConfig(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers) }
        set {
            // Set both in one operation, but only post one notification
            defaults.set(Int(newValue.keyCode), forKey: hotkeyKeyCodeKey)
            defaults.set(Int(newValue.modifiers), forKey: hotkeyModifiersKey)
            NotificationCenter.default.post(name: .settingsHotkeyDidChange, object: self)
        }
    }

    var appLanguage: AppLanguage {
        get {
            guard let raw = defaults.string(forKey: appLanguageKey),
                  let value = AppLanguage(rawValue: raw) else {
                return .system
            }
            return value
        }
        set {
            objectWillChange.send()
            defaults.set(newValue.rawValue, forKey: appLanguageKey)
            NotificationCenter.default.post(name: .settingsLanguageDidChange, object: self)
        }
    }
}

enum HotzoneCorner: String, CaseIterable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

struct HotkeyConfig: Equatable, Sendable {
    let keyCode: UInt16
    let modifiers: UInt64

    // Default hotkey: Option + Space
    static let defaultConfig = HotkeyConfig(keyCode: 49, modifiers: 0x80000)

    var displayString: String {
        var parts: [String] = []

        // Check modifier flags
        if modifiers & 0x40000 != 0 { parts.append("⌃") }  // Control
        if modifiers & 0x80000 != 0 { parts.append("⌥") }  // Option
        if modifiers & 0x20000 != 0 { parts.append("⇧") }  // Shift
        if modifiers & 0x100000 != 0 { parts.append("⌘") } // Command

        // Add key name
        parts.append(keyCodeToString(keyCode))

        return parts.joined()
    }

    private func keyCodeToString(_ code: UInt16) -> String {
        // Common key codes to display names
        switch code {
        case 49: return "Space"
        case 36: return "↩"  // Return
        case 48: return "⇥"  // Tab
        case 51: return "⌫"  // Delete
        case 53: return "⎋"  // Escape
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 50: return "`"
        case 65: return "."  // Keypad
        case 67: return "*"  // Keypad
        case 69: return "+"  // Keypad
        case 71: return "⌧"  // Clear
        case 75: return "/"  // Keypad
        case 76: return "⌤"  // Enter
        case 78: return "-"  // Keypad
        case 81: return "="  // Keypad
        case 82: return "0"  // Keypad
        case 83: return "1"  // Keypad
        case 84: return "2"  // Keypad
        case 85: return "3"  // Keypad
        case 86: return "4"  // Keypad
        case 87: return "5"  // Keypad
        case 88: return "6"  // Keypad
        case 89: return "7"  // Keypad
        case 91: return "8"  // Keypad
        case 92: return "9"  // Keypad
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 118: return "F4"
        case 119: return "F2"
        case 120: return "F1"
        case 122: return "F1"
        default: return "Key\(code)"
        }
    }
}

extension Notification.Name {
    static let settingsHistoryLimitDidChange = Notification.Name("SettingsStore.historyLimitDidChange")
    static let settingsHotzoneDidChange = Notification.Name("SettingsStore.hotzoneDidChange")
    static let settingsForceTouchDidChange = Notification.Name("SettingsStore.forceTouchDidChange")
    static let settingsHotkeyDidChange = Notification.Name("SettingsStore.hotkeyDidChange")
    static let settingsWhisperPortDidChange = Notification.Name("SettingsStore.whisperPortDidChange")
    static let settingsLanguageDidChange = Notification.Name("SettingsStore.languageDidChange")
}
