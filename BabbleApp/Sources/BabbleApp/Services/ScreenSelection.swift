import AppKit
import CoreGraphics

struct ScreenSelection {
    static func screenFrameContaining(rect: CGRect, screens: [CGRect]) -> CGRect? {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        return screens.first { $0.contains(center) }
    }

    static func frontmostScreen() -> NSScreen? {
        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let options: CGWindowListOption = [.excludeDesktopElements, .optionOnScreenOnly]
        guard let infoList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        let pid = app.processIdentifier
        let windowInfo = infoList.first { info in
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t
            let layer = info[kCGWindowLayer as String] as? Int
            return ownerPID == pid && layer == 0 && info[kCGWindowBounds as String] != nil
        }

        guard let boundsDict = windowInfo?[kCGWindowBounds as String] as? [String: CGFloat] else {
            return nil
        }

        let windowBounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        let screenFrames = NSScreen.screens.map { $0.visibleFrame }
        guard let targetFrame = screenFrameContaining(rect: windowBounds, screens: screenFrames) else {
            return nil
        }

        return NSScreen.screens.first { $0.visibleFrame.equalTo(targetFrame) }
    }
}
