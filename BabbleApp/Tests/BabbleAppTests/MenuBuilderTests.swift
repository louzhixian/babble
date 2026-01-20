import AppKit
import XCTest
@testable import BabbleApp

final class MenuBuilderTests: XCTestCase {
    @MainActor
    func testMenuDoesNotIncludeShowHidePanelItems() {
        let controller = VoiceInputController()
        let store = SettingsStore()
        let menu = MenuBuilder().makeMenu(controller: controller, settingsStore: store)
        let titles = menu.items.map { $0.title }

        XCTAssertFalse(titles.contains("Show Panel"))
        XCTAssertFalse(titles.contains("Hide Panel"))
    }
}
