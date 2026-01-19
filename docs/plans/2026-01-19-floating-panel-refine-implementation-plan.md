# Floating Panel + Refine Multi-Select Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Improve the floating panel layout/positioning and add Refine multi-select with deterministic prompt composition.

**Architecture:** Introduce small, testable helpers for panel layout and prompt composition, then wire them into the existing controller/services. Persist user settings via a lightweight settings store and update UI to reflect new options.

**Tech Stack:** Swift 6.2, SwiftUI/AppKit (NSPanel), FoundationModels, SPM tests.

@superpowers:test-driven-development

---

### Task 1: Floating panel position model + layout helper

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Models/FloatingPanelPosition.swift`
- Create: `BabbleApp/Sources/BabbleApp/Services/FloatingPanelLayout.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/FloatingPanelLayoutTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class FloatingPanelLayoutTests: XCTestCase {
    func testPositionFramesUseScreenBoundsWithMargin() {
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        let size = CGSize(width: 240, height: 64)
        let margin: CGFloat = 20

        let layout = FloatingPanelLayout(margin: margin)

        XCTAssertEqual(
            layout.frame(for: .top, panelSize: size, in: screen).origin.y,
            screen.maxY - margin - size.height
        )
        XCTAssertEqual(
            layout.frame(for: .bottom, panelSize: size, in: screen).origin.y,
            screen.minY + margin
        )
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter FloatingPanelLayoutTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

```swift
public enum FloatingPanelPosition: String, CaseIterable {
    case top, bottom, left, right, center
}

public struct FloatingPanelLayout {
    let margin: CGFloat

    func frame(for position: FloatingPanelPosition, panelSize: CGSize, in screen: CGRect) -> CGRect {
        var origin = CGPoint(x: screen.midX - panelSize.width / 2,
                             y: screen.midY - panelSize.height / 2)
        switch position {
        case .top:
            origin.y = screen.maxY - margin - panelSize.height
        case .bottom:
            origin.y = screen.minY + margin
        case .left:
            origin.x = screen.minX + margin
        case .right:
            origin.x = screen.maxX - margin - panelSize.width
        case .center:
            break
        }
        return CGRect(origin: origin, size: panelSize)
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter FloatingPanelLayoutTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Models/FloatingPanelPosition.swift \
       BabbleApp/Sources/BabbleApp/Services/FloatingPanelLayout.swift \
       BabbleApp/Tests/BabbleAppTests/FloatingPanelLayoutTests.swift
git commit -m "feat: add floating panel position model and layout helper"
```

---

### Task 2: Settings storage for panel position

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/SettingsStore.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/SettingsStoreTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class SettingsStoreTests: XCTestCase {
    func testPersistsFloatingPanelPosition() {
        let store = SettingsStore(userDefaults: UserDefaults(suiteName: "SettingsStoreTests")!)
        store.floatingPanelPosition = .left
        XCTAssertEqual(store.floatingPanelPosition, .left)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter SettingsStoreTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

```swift
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
```

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter SettingsStoreTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/SettingsStore.swift \
       BabbleApp/Tests/BabbleAppTests/SettingsStoreTests.swift
git commit -m "feat: persist floating panel position in settings"
```

---

### Task 3: Floating panel view updates (size, color, visibility)

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Views/FloatingPanelWindow.swift`
- Modify: `BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/FloatingPanelStateTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class FloatingPanelStateTests: XCTestCase {
    func testMicColorIsGreenWhenRecording() {
        let state = FloatingPanelState(status: .recording, message: nil)
        XCTAssertEqual(state.micColor, .green)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter FloatingPanelStateTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

```swift
enum FloatingPanelStatus {
    case idle
    case recording
    case processing
    case pasteFailed
}

struct FloatingPanelState {
    let status: FloatingPanelStatus
    let message: String?

    var micColor: NSColor {
        switch status {
        case .recording:
            return .systemGreen
        case .pasteFailed:
            return .systemOrange
        default:
            return .secondaryLabelColor
        }
    }
}
```

Update `FloatingPanelWindow.swift` to:
- Use `FloatingPanelState` for color and message
- Measure intrinsic content size and pass to `FloatingPanelLayout`
- Reposition on screen change or settings updates

Update `VoiceInputController.swift` to:
- Set state to `.recording` on activation
- Set state to `.processing` after recording ends
- Hide panel on successful paste
- Set state to `.pasteFailed` with message on failure

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter FloatingPanelStateTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Views/FloatingPanelWindow.swift \
       BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift \
       BabbleApp/Tests/BabbleAppTests/FloatingPanelStateTests.swift
git commit -m "feat: update floating panel state, size, and visibility"
```

---

### Task 4: Paste result handling (success/failure)

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Services/PasteService.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/PasteServiceTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class PasteServiceTests: XCTestCase {
    func testPasteReturnsFailureWhenEventTapDenied() {
        let service = PasteService(eventPoster: .failingStub)
        XCTAssertFalse(service.pasteFromClipboard())
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter PasteServiceTests`
Expected: FAIL (missing stub/return value)

**Step 3: Write minimal implementation**

- Change `pasteFromClipboard()` to return `Bool`
- Inject a small `EventPoster` protocol so tests can stub success/failure

```swift
protocol EventPoster {
    func postPaste() -> Bool
}
```

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter PasteServiceTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/PasteService.swift \
       BabbleApp/Tests/BabbleAppTests/PasteServiceTests.swift
git commit -m "feat: return paste success and support stubbing"
```

---

### Task 5: Refine multi-select + prompt composition

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Services/RefineService.swift`
- Modify: `BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift`
- Modify: `BabbleApp/Sources/BabbleApp/Views/SettingsView.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/RefinePromptComposerTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class RefinePromptComposerTests: XCTestCase {
    func testPromptCompositionUsesFixedOrder() {
        let composer = RefinePromptComposer()
        let prompt = composer.prompt(for: [.polish, .correct])
        XCTAssertTrue(prompt.contains("纠错"))
        XCTAssertTrue(prompt.contains("润色"))
        XCTAssertLessThan(prompt.range(of: "纠错")!.lowerBound, prompt.range(of: "润色")!.lowerBound)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter RefinePromptComposerTests`
Expected: FAIL (missing composer)

**Step 3: Write minimal implementation**

- Introduce `RefineOption` (Set) with fixed ordering
- Add `RefinePromptComposer` that joins prompts in order: correct -> punctuate -> polish
- Update `RefineService` to accept `[RefineOption]` (or `Set`) and skip when empty/off
- Update `VoiceInputController` to pass selected options
- Update `SettingsView` to show multi-select and an explicit Off toggle

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter RefinePromptComposerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/RefineService.swift \
       BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift \
       BabbleApp/Sources/BabbleApp/Views/SettingsView.swift \
       BabbleApp/Tests/BabbleAppTests/RefinePromptComposerTests.swift
git commit -m "feat: add refine multi-select and prompt composition"
```

---

### Task 6: Wire panel position into UI settings

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Views/SettingsView.swift`
- Modify: `BabbleApp/Sources/BabbleApp/Views/FloatingPanelWindow.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/SettingsViewModelTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class SettingsViewModelTests: XCTestCase {
    func testSelectingPositionUpdatesStore() {
        let store = SettingsStore(userDefaults: UserDefaults(suiteName: "SettingsViewModelTests")!)
        let model = SettingsViewModel(store: store)
        model.floatingPanelPosition = .right
        XCTAssertEqual(store.floatingPanelPosition, .right)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter SettingsViewModelTests`
Expected: FAIL (missing model)

**Step 3: Write minimal implementation**

- Add `SettingsViewModel` with `floatingPanelPosition` binding to `SettingsStore`
- Update settings UI to present 5-position picker
- Update `FloatingPanelWindow` to observe changes and re-layout

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter SettingsViewModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Views/SettingsView.swift \
       BabbleApp/Sources/BabbleApp/Views/FloatingPanelWindow.swift \
       BabbleApp/Tests/BabbleAppTests/SettingsViewModelTests.swift
git commit -m "feat: add floating panel position setting"
```
