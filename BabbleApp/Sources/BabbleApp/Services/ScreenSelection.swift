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

        // CGWindowListCopyWindowInfo uses screen coordinates (origin at top-left of main screen)
        let windowBounds = CGRect(
            x: boundsDict["X"] ?? 0,
            y: boundsDict["Y"] ?? 0,
            width: boundsDict["Width"] ?? 0,
            height: boundsDict["Height"] ?? 0
        )

        // Find the screen that contains the window center using screen coordinates
        let windowCenter = CGPoint(x: windowBounds.midX, y: windowBounds.midY)

        // NSScreen.frame uses Cocoa coordinates (origin at bottom-left of main screen)
        // We need to convert or compare in the same coordinate system
        // Use NSScreen.frame (not visibleFrame) and convert to screen coordinates
        guard let mainScreen = NSScreen.screens.first else { return nil }
        let mainScreenHeight = mainScreen.frame.height

        return NSScreen.screens.first { screen in
            // Convert NSScreen frame to screen coordinates (flip Y)
            let screenFrame = screen.frame
            let screenTop = mainScreenHeight - screenFrame.maxY
            let screenRect = CGRect(
                x: screenFrame.minX,
                y: screenTop,
                width: screenFrame.width,
                height: screenFrame.height
            )
            return screenRect.contains(windowCenter)
        }
    }
}
