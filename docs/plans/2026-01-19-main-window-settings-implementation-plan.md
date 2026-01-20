# Main Window + Settings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add the full main window (history, inline edit, compare/edit, settings) and trackpad hotzone trigger, completing the non-MVP features in the design.

**Architecture:** Introduce in-memory history and expanded settings models, then build SwiftUI views for history, compare/edit, and settings within a single navigation window. Add a hotzone trigger service that maps cursor position to a configurable corner and dispatches the existing recording flow.

**Tech Stack:** Swift 6.2, SwiftUI/AppKit, UserDefaults, XCTest.

@superpowers:test-driven-development

---

### Task 1: History models and store with retention

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Models/HistoryRecord.swift`
- Create: `BabbleApp/Sources/BabbleApp/Services/HistoryStore.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/HistoryStoreTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class HistoryStoreTests: XCTestCase {
    func testKeepsNewestWhenExceedingLimit() {
        let store = HistoryStore(limit: 2)
        store.append(HistoryRecord.sample(id: "1"))
        store.append(HistoryRecord.sample(id: "2"))
        store.append(HistoryRecord.sample(id: "3"))

        XCTAssertEqual(store.records.map { $0.id }, ["3", "2"])
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter HistoryStoreTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

```swift
struct HistoryRecord: Identifiable, Equatable {
    let id: String
    let timestamp: Date
    let rawText: String
    let refinedText: String
    let refineOptions: [RefineOption]
    let targetAppName: String?
    var editedText: String?

    static func sample(id: String) -> HistoryRecord {
        HistoryRecord(
            id: id,
            timestamp: Date(),
            rawText: "raw",
            refinedText: "refined",
            refineOptions: [],
            targetAppName: nil,
            editedText: nil
        )
    }
}

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [HistoryRecord] = []
    private let limit: Int

    init(limit: Int) { self.limit = limit }

    func append(_ record: HistoryRecord) {
        records.insert(record, at: 0)
        if records.count > limit {
            records = Array(records.prefix(limit))
        }
    }
}
```

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter HistoryStoreTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Models/HistoryRecord.swift \
       BabbleApp/Sources/BabbleApp/Services/HistoryStore.swift \
       BabbleApp/Tests/BabbleAppTests/HistoryStoreTests.swift
git commit -m "feat: add in-memory history store with limit"
```

---

### Task 2: SettingsStore expansion and view model

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Services/SettingsStore.swift`
- Create: `BabbleApp/Sources/BabbleApp/Models/SettingsViewModel.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/SettingsStoreExpandedTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class SettingsStoreExpandedTests: XCTestCase {
    func testPersistsHistoryLimit() {
        let defaults = UserDefaults(suiteName: "SettingsStoreExpandedTests")!
        defaults.removePersistentDomain(forName: "SettingsStoreExpandedTests")
        let store = SettingsStore(userDefaults: defaults)

        store.historyLimit = 200
        XCTAssertEqual(store.historyLimit, 200)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter SettingsStoreExpandedTests`
Expected: FAIL (missing property)

**Step 3: Write minimal implementation**

- Add fields to `SettingsStore`:
  - `historyLimit` (Int)
  - `recordTargetApp` (Bool)
  - `autoRefine` (Bool)
  - `defaultRefineOptions` ([RefineOption])
  - `customPrompts` ([RefineOption: String])
  - `defaultLanguage` (String)
  - `whisperPort` (Int)
  - `clearClipboardAfterCopy` (Bool)
  - `playSoundOnCopy` (Bool)
  - `hotzoneEnabled` (Bool)
  - `hotzoneCorner` (enum)
  - `hotzoneHoldSeconds` (Double)

- Add `SettingsViewModel` with `@Published` bindings to `SettingsStore`.

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter SettingsStoreExpandedTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/SettingsStore.swift \
       BabbleApp/Sources/BabbleApp/Models/SettingsViewModel.swift \
       BabbleApp/Tests/BabbleAppTests/SettingsStoreExpandedTests.swift
git commit -m "feat: expand settings store and view model"
```

---

### Task 3: Main window scaffold with navigation

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/BabbleApp.swift`
- Create: `BabbleApp/Sources/BabbleApp/UI/MainWindow/MainWindowView.swift`
- Create: `BabbleApp/Sources/BabbleApp/UI/MainWindow/SidebarView.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/MainWindowRoutingTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class MainWindowRoutingTests: XCTestCase {
    func testDefaultRouteIsHistory() {
        let router = MainWindowRouter()
        XCTAssertEqual(router.selection, .history)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter MainWindowRoutingTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

- Add `MainWindowRouter` with enum `.history`, `.compareEdit`, `.settings`.
- `BabbleApp` uses `WindowGroup` with `MainWindowView`.
- `MainWindowView` uses `NavigationSplitView` with `SidebarView`.

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter MainWindowRoutingTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/BabbleApp.swift \
       BabbleApp/Sources/BabbleApp/UI/MainWindow/MainWindowView.swift \
       BabbleApp/Sources/BabbleApp/UI/MainWindow/SidebarView.swift \
       BabbleApp/Tests/BabbleAppTests/MainWindowRoutingTests.swift
git commit -m "feat: add main window navigation scaffold"
```

---

### Task 4: History list + inline edit + copy

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/UI/History/HistoryView.swift`
- Create: `BabbleApp/Sources/BabbleApp/UI/History/HistoryRowView.swift`
- Modify: `BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/HistoryRowViewModelTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class HistoryRowViewModelTests: XCTestCase {
    func testEditingDefaultsToSelectedVariant() {
        let record = HistoryRecord.sample(id: "1")
        let model = HistoryRowViewModel(record: record)
        model.selectedVariant = .refined
        model.beginEditing()
        XCTAssertEqual(model.editingText, record.refinedText)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter HistoryRowViewModelTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

- Add `HistoryRowViewModel` with `selectedVariant` (raw/refined), `editingText`, `isEditing`.
- `HistoryRowView` shows fields and inline editor with “复制” button.
- Copy button uses `PasteService.copyToClipboard` and optional `playSoundOnCopy`/`clearClipboardAfterCopy`.
- `VoiceInputController` appends new `HistoryRecord` after transcription/refine.

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter HistoryRowViewModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/UI/History/HistoryView.swift \
       BabbleApp/Sources/BabbleApp/UI/History/HistoryRowView.swift \
       BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift \
       BabbleApp/Tests/BabbleAppTests/HistoryRowViewModelTests.swift
git commit -m "feat: add history list with inline edit and copy"
```

---

### Task 5: Compare/Edit view

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/UI/CompareEdit/CompareEditView.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/CompareEditViewModelTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class CompareEditViewModelTests: XCTestCase {
    func testDefaultsToRefinedText() {
        let record = HistoryRecord.sample(id: "1")
        let model = CompareEditViewModel(record: record)
        XCTAssertEqual(model.editingText, record.refinedText)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter CompareEditViewModelTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

- Add `CompareEditViewModel` and view with side-by-side raw/refined and an editor.
- Provide “复制” action only.

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter CompareEditViewModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/UI/CompareEdit/CompareEditView.swift \
       BabbleApp/Tests/BabbleAppTests/CompareEditViewModelTests.swift
git commit -m "feat: add compare/edit view"
```

---

### Task 6: Settings view UI

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/UI/Settings/SettingsView.swift`
- Modify: `BabbleApp/Sources/BabbleApp/UI/MainWindow/MainWindowView.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/SettingsViewModelTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class SettingsViewModelTests: XCTestCase {
    func testUpdatesHotzoneEnabled() {
        let defaults = UserDefaults(suiteName: "SettingsViewModelTests")!
        let store = SettingsStore(userDefaults: defaults)
        let model = SettingsViewModel(store: store)
        model.hotzoneEnabled = true
        XCTAssertTrue(store.hotzoneEnabled)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter SettingsViewModelTests`
Expected: FAIL (missing model)

**Step 3: Write minimal implementation**

- Implement `SettingsView` sections for each group.
- Wire to `SettingsViewModel`.

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter SettingsViewModelTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/UI/Settings/SettingsView.swift \
       BabbleApp/Sources/BabbleApp/UI/MainWindow/MainWindowView.swift \
       BabbleApp/Tests/BabbleAppTests/SettingsViewModelTests.swift
git commit -m "feat: add settings view"
```

---

### Task 7: Refine prompt overrides + auto-refine

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Services/RefineService.swift`
- Modify: `BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/RefinePromptComposerTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class RefinePromptComposerTests: XCTestCase {
    func testCustomPromptOverridesDefault() {
        let composer = RefinePromptComposer(customPrompts: [.correct: "自定义纠错"]) 
        let prompt = composer.prompt(for: [.correct])
        XCTAssertEqual(prompt, "自定义纠错")
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter RefinePromptComposerTests`
Expected: FAIL (missing initializer/behavior)

**Step 3: Write minimal implementation**

- Add custom prompt overrides in `RefinePromptComposer`.
- Use settings `autoRefine` and `defaultRefineOptions` in controller.

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter RefinePromptComposerTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/RefineService.swift \
       BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift \
       BabbleApp/Tests/BabbleAppTests/RefinePromptComposerTests.swift
git commit -m "feat: add refine prompt overrides and auto refine"
```

---

### Task 8: Hotzone trigger service

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/HotzoneTrigger.swift`
- Modify: `BabbleApp/Sources/BabbleApp/Services/HotkeyManager.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/HotzoneDetectorTests.swift`

**Step 1: Write the failing test**

```swift
import CoreGraphics
import XCTest
@testable import BabbleApp

final class HotzoneDetectorTests: XCTestCase {
    func testDetectsBottomLeftHotzone() {
        let detector = HotzoneDetector(corner: .bottomLeft, inset: 32)
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        XCTAssertTrue(detector.isInside(point: CGPoint(x: 10, y: 10), in: screen))
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter HotzoneDetectorTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

- Add `HotzoneCorner` enum and `HotzoneDetector`.
- Implement `HotzoneTrigger` that polls cursor location on timer when enabled.
- When cursor stays in hotzone for `hotzoneHoldSeconds`, trigger `HotkeyEvent.longPressStart/End` or direct callback.

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter HotzoneDetectorTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/HotzoneTrigger.swift \
       BabbleApp/Sources/BabbleApp/Services/HotkeyManager.swift \
       BabbleApp/Tests/BabbleAppTests/HotzoneDetectorTests.swift
git commit -m "feat: add hotzone trigger"
```

---

### Task 9: Wire main window + settings into app

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/AppDelegate.swift`
- Modify: `BabbleApp/Sources/BabbleApp/BabbleApp.swift`
- Test: `BabbleApp/Tests/BabbleAppTests/AppWiringTests.swift`

**Step 1: Write the failing test**

```swift
import XCTest
@testable import BabbleApp

final class AppWiringTests: XCTestCase {
    func testMainWindowUsesSharedStores() {
        let coordinator = AppCoordinator()
        XCTAssertNotNil(coordinator.historyStore)
    }
}
```

**Step 2: Run test to verify it fails**

Run: `cd BabbleApp && swift test --filter AppWiringTests`
Expected: FAIL (missing types)

**Step 3: Write minimal implementation**

- Add `AppCoordinator` to share `HistoryStore`, `SettingsStore`, `VoiceInputController`.
- AppDelegate uses coordinator and passes to views.

**Step 4: Run test to verify it passes**

Run: `cd BabbleApp && swift test --filter AppWiringTests`
Expected: PASS

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/AppDelegate.swift \
       BabbleApp/Sources/BabbleApp/BabbleApp.swift \
       BabbleApp/Tests/BabbleAppTests/AppWiringTests.swift
git commit -m "feat: wire main window and shared stores"
```
