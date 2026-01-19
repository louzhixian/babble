enum FloatingPanelPosition: String, CaseIterable {
    case top
    case bottom
    case left
    case right
    case center

    var displayName: String {
        switch self {
        case .top:
            return "上"
        case .bottom:
            return "下"
        case .left:
            return "左"
        case .right:
            return "右"
        case .center:
            return "中"
        }
    }
}
