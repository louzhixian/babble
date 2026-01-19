import AppKit

enum FloatingPanelStatus {
    case idle
    case recording
    case processing
    case pasteFailed
    case error
}

struct FloatingPanelState {
    let status: FloatingPanelStatus
    let message: String?

    var micColor: NSColor {
        switch status {
        case .recording:
            return .systemGreen
        case .pasteFailed, .error:
            return .systemOrange
        default:
            return .secondaryLabelColor
        }
    }
}
