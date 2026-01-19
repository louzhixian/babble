import Foundation

final class SettingsStore {
    private let defaults: UserDefaults
    private let positionKey = "floatingPanelPosition"

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
}
