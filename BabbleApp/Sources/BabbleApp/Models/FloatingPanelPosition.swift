enum FloatingPanelPosition: String, CaseIterable, Sendable {
    case top
    case bottom
    case left
    case right
    case center

    func displayName(for language: AppLanguage) -> String {
        let l = L10n.strings(for: language)
        switch self {
        case .top: return l.positionTop
        case .bottom: return l.positionBottom
        case .left: return l.positionLeft
        case .right: return l.positionRight
        case .center: return l.positionCenter
        }
    }

    /// Legacy display name for menu (uses system language)
    var displayName: String {
        displayName(for: .system)
    }
}
