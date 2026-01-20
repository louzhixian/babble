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

    init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }

    var floatingPanelPosition: FloatingPanelPosition {
        get {
            guard let raw = defaults.string(forKey: positionKey),
                  let value = FloatingPanelPosition(rawValue: raw) else {
                return .top
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
        get { defaults.string(forKey: refinePromptKey) ?? "" }
        set { defaults.set(newValue, forKey: refinePromptKey) }
    }

    var effectiveRefinePrompt: String {
        let custom = refinePrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return custom.isEmpty ? RefineService.defaultPrompt : custom
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
        get { defaults.object(forKey: forceTouchEnabledKey) as? Bool ?? false }
        set {
            defaults.set(newValue, forKey: forceTouchEnabledKey)
            NotificationCenter.default.post(name: .settingsForceTouchDidChange, object: self)
        }
    }

    var forceTouchHoldSeconds: Double {
        get {
            let stored = defaults.double(forKey: forceTouchHoldSecondsKey)
            return stored > 0 ? stored : 2.0
        }
        set {
            defaults.set(newValue, forKey: forceTouchHoldSecondsKey)
            NotificationCenter.default.post(name: .settingsForceTouchDidChange, object: self)
        }
    }
}

enum HotzoneCorner: String, CaseIterable, Sendable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

extension Notification.Name {
    static let settingsHistoryLimitDidChange = Notification.Name("SettingsStore.historyLimitDidChange")
    static let settingsHotzoneDidChange = Notification.Name("SettingsStore.hotzoneDidChange")
    static let settingsForceTouchDidChange = Notification.Name("SettingsStore.forceTouchDidChange")
    static let settingsWhisperPortDidChange = Notification.Name("SettingsStore.whisperPortDidChange")
}
