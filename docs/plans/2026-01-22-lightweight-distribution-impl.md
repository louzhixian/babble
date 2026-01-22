# Lightweight Distribution Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Reduce Babble.app from ~760MB to ~1MB by downloading whisper-service binary on first launch.

**Architecture:** PyInstaller packages whisper-service as standalone binary hosted on GitHub Releases. Swift app includes DownloadManager that downloads binary to ~/Library/Application Support/Babble/ on first launch. ProcessManager modified to use downloaded binary instead of bundled venv.

**Tech Stack:** PyInstaller (Python packaging), Swift URLSession (downloads), GitHub Releases (hosting)

---

## Task 1: PyInstaller Build Script

**Files:**
- Create: `whisper-service/build.sh`
- Create: `whisper-service/whisper-service.spec`

**Step 1: Create PyInstaller spec file**

Create `whisper-service/whisper-service.spec`:
```python
# -*- mode: python ; coding: utf-8 -*-

block_cipher = None

a = Analysis(
    ['server.py'],
    pathex=[],
    binaries=[],
    datas=[('config.yaml', '.')],
    hiddenimports=[
        'mlx',
        'mlx.core',
        'mlx_whisper',
        'uvicorn.logging',
        'uvicorn.protocols.http',
        'uvicorn.protocols.http.auto',
        'uvicorn.protocols.websockets',
        'uvicorn.protocols.websockets.auto',
        'uvicorn.lifespan',
        'uvicorn.lifespan.on',
    ],
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    win_no_prefer_redirects=False,
    win_private_assemblies=False,
    cipher=block_cipher,
    noarchive=False,
)

pyz = PYZ(a.pure, a.zipped_data, cipher=block_cipher)

exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.zipfiles,
    a.datas,
    [],
    name='whisper-service',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=False,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch='arm64',
    codesign_identity=None,
    entitlements_file=None,
)
```

**Step 2: Create build script**

Create `whisper-service/build.sh`:
```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "=== Setting up build environment ==="
if [ ! -d ".venv" ]; then
    python3 -m venv .venv
fi
source .venv/bin/activate

echo "=== Installing dependencies ==="
pip install -q -r requirements.txt
pip install -q pyinstaller

echo "=== Building with PyInstaller ==="
pyinstaller --clean --noconfirm whisper-service.spec

echo "=== Generating checksum ==="
cd dist
shasum -a 256 whisper-service > whisper-service.sha256
cat whisper-service.sha256

echo ""
echo "=== Build complete ==="
echo "Binary: $SCRIPT_DIR/dist/whisper-service"
echo "Checksum: $SCRIPT_DIR/dist/whisper-service.sha256"
ls -lh whisper-service
```

**Step 3: Make build script executable and test**

Run:
```bash
chmod +x whisper-service/build.sh
cd whisper-service && ./build.sh
```

Expected: Binary created at `whisper-service/dist/whisper-service`

**Step 4: Commit**

```bash
git add whisper-service/build.sh whisper-service/whisper-service.spec
git commit -m "feat: add PyInstaller build script for whisper-service"
```

---

## Task 2: DownloadManager Implementation

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/DownloadManager.swift`

**Step 1: Create DownloadManager**

Create `BabbleApp/Sources/BabbleApp/Services/DownloadManager.swift`:
```swift
// BabbleApp/Sources/BabbleApp/Services/DownloadManager.swift

import Foundation

enum DownloadState: Equatable {
    case idle
    case checking
    case downloading(progress: Double, downloadedBytes: Int64, totalBytes: Int64)
    case verifying
    case failed(error: String, retryCount: Int)
    case completed
}

enum DownloadError: Error, LocalizedError {
    case networkError(String)
    case checksumMismatch
    case fileSystemError(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "Network error: \(msg)"
        case .checksumMismatch: return "Download corrupted, checksum mismatch"
        case .fileSystemError(let msg): return "File system error: \(msg)"
        case .invalidResponse: return "Invalid server response"
        }
    }
}

@MainActor
class DownloadManager: ObservableObject {
    @Published private(set) var state: DownloadState = .idle

    private let maxRetries = 3
    private var currentRetryCount = 0

    // GitHub Release URLs
    private let releaseVersion = "whisper-v1.0.0"
    private let repoOwner = "louzhixian"
    private let repoName = "babble"

    var binaryURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/download/\(releaseVersion)/whisper-service")!
    }

    var checksumURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/download/\(releaseVersion)/whisper-service.sha256")!
    }

    var manualDownloadURL: URL {
        URL(string: "https://github.com/\(repoOwner)/\(repoName)/releases/tag/\(releaseVersion)")!
    }

    // Local paths
    var supportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Babble")
    }

    var whisperServicePath: URL {
        supportDirectory.appendingPathComponent("whisper-service")
    }

    var checksumPath: URL {
        supportDirectory.appendingPathComponent("whisper-service.sha256")
    }

    // MARK: - Public Methods

    func isDownloadNeeded() -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: whisperServicePath.path) else { return true }
        guard fm.fileExists(atPath: checksumPath.path) else { return true }
        return !verifyChecksum()
    }

    func downloadIfNeeded() async throws {
        guard isDownloadNeeded() else {
            state = .completed
            return
        }

        try await download()
    }

    func retry() async throws {
        currentRetryCount = 0
        try await download()
    }

    // MARK: - Private Methods

    private func download() async throws {
        state = .checking

        // Ensure support directory exists
        try createSupportDirectoryIfNeeded()

        // Download checksum first
        state = .downloading(progress: 0, downloadedBytes: 0, totalBytes: 0)
        let expectedChecksum = try await downloadChecksum()

        // Download binary with progress
        try await downloadBinary()

        // Verify checksum
        state = .verifying
        guard verifyChecksum(expected: expectedChecksum) else {
            // Delete corrupted file
            try? FileManager.default.removeItem(at: whisperServicePath)

            currentRetryCount += 1
            if currentRetryCount < maxRetries {
                // Auto retry
                try await download()
                return
            }

            state = .failed(error: "Checksum verification failed", retryCount: currentRetryCount)
            throw DownloadError.checksumMismatch
        }

        // Make executable
        try makeExecutable()

        state = .completed
    }

    private func createSupportDirectoryIfNeeded() throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: supportDirectory.path) {
            try fm.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        }
    }

    private func downloadChecksum() async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: checksumURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DownloadError.invalidResponse
        }

        guard let checksumString = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: " ").first else {
            throw DownloadError.invalidResponse
        }

        // Save checksum file
        try checksumString.write(to: checksumPath, atomically: true, encoding: .utf8)

        return checksumString
    }

    private func downloadBinary() async throws {
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: binaryURL)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw DownloadError.invalidResponse
        }

        let totalBytes = httpResponse.expectedContentLength
        var downloadedBytes: Int64 = 0
        var data = Data()
        data.reserveCapacity(Int(totalBytes))

        for try await byte in asyncBytes {
            data.append(byte)
            downloadedBytes += 1

            // Update progress every 100KB
            if downloadedBytes % (100 * 1024) == 0 {
                let progress = totalBytes > 0 ? Double(downloadedBytes) / Double(totalBytes) : 0
                state = .downloading(progress: progress, downloadedBytes: downloadedBytes, totalBytes: totalBytes)
            }
        }

        // Final progress update
        state = .downloading(progress: 1.0, downloadedBytes: downloadedBytes, totalBytes: totalBytes)

        // Write to file
        try data.write(to: whisperServicePath)
    }

    private func verifyChecksum(expected: String? = nil) -> Bool {
        let expectedHash: String
        if let expected = expected {
            expectedHash = expected
        } else {
            guard let stored = try? String(contentsOf: checksumPath, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines) else {
                return false
            }
            expectedHash = stored
        }

        guard let data = try? Data(contentsOf: whisperServicePath) else {
            return false
        }

        let actualHash = sha256(data: data)
        return actualHash.lowercased() == expectedHash.lowercased()
    }

    private func sha256(data: Data) -> String {
        import CryptoKit
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }

    private func makeExecutable() throws {
        let fm = FileManager.default
        var attributes = try fm.attributesOfItem(atPath: whisperServicePath.path)
        let currentPermissions = (attributes[.posixPermissions] as? Int) ?? 0o644
        try fm.setAttributes([.posixPermissions: currentPermissions | 0o111], ofItemAtPath: whisperServicePath.path)
    }
}
```

**Step 2: Fix import for CryptoKit**

The sha256 function needs CryptoKit. Update the file to add proper import at top:
```swift
import Foundation
import CryptoKit
```

And update sha256 function:
```swift
private func sha256(data: Data) -> String {
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}
```

**Step 3: Build to verify compilation**

Run:
```bash
cd BabbleApp && swift build
```

Expected: Build succeeds

**Step 4: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/DownloadManager.swift
git commit -m "feat: add DownloadManager for whisper-service binary download"
```

---

## Task 3: Download UI View

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/UI/Download/DownloadView.swift`

**Step 1: Create DownloadView**

Create directory and file `BabbleApp/Sources/BabbleApp/UI/Download/DownloadView.swift`:
```swift
// BabbleApp/Sources/BabbleApp/UI/Download/DownloadView.swift

import SwiftUI

struct DownloadView: View {
    @ObservedObject var downloadManager: DownloadManager
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            // Icon
            Image(systemName: "arrow.down.circle")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            // Title
            Text("Setting Up Babble")
                .font(.title2)
                .fontWeight(.semibold)

            // Status content
            statusContent

            Spacer()
        }
        .padding(40)
        .frame(width: 400, height: 300)
        .onChange(of: downloadManager.state) { _, newState in
            if newState == .completed {
                onComplete()
            }
        }
    }

    @ViewBuilder
    private var statusContent: some View {
        switch downloadManager.state {
        case .idle, .checking:
            ProgressView()
                .scaleEffect(0.8)
            Text("Checking for updates...")
                .foregroundStyle(.secondary)

        case .downloading(let progress, let downloaded, let total):
            VStack(spacing: 12) {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)

                HStack {
                    Text("Downloading speech engine...")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(formatBytes(downloaded)) / \(formatBytes(total))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .font(.caption)
            }

        case .verifying:
            ProgressView()
                .scaleEffect(0.8)
            Text("Verifying download...")
                .foregroundStyle(.secondary)

        case .failed(let error, let retryCount):
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 32))
                    .foregroundStyle(.orange)

                Text("Download Failed")
                    .font(.headline)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                if retryCount < 3 {
                    Button("Retry") {
                        Task {
                            try? await downloadManager.retry()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button("Manual Download") {
                    NSWorkspace.shared.open(downloadManager.manualDownloadURL)
                }
                .buttonStyle(.link)

                Text("Download the file and place it in:\n~/Library/Application Support/Babble/")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }

        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.green)
            Text("Ready!")
                .foregroundStyle(.secondary)
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
```

**Step 2: Build to verify**

Run:
```bash
cd BabbleApp && swift build
```

Expected: Build succeeds

**Step 3: Commit**

```bash
mkdir -p BabbleApp/Sources/BabbleApp/UI/Download
git add BabbleApp/Sources/BabbleApp/UI/Download/DownloadView.swift
git commit -m "feat: add DownloadView for first-launch download UI"
```

---

## Task 4: Update ProcessManager

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Services/ProcessManager.swift`

**Step 1: Update ProcessManager to use downloaded binary**

Replace the path detection logic in ProcessManager init:
```swift
init() {
    let fileManager = FileManager.default

    // Set up health check URL and session
    session = URLSession.shared

    // Primary path: downloaded binary in Application Support
    let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Babble")
    let downloadedBinary = supportDir.appendingPathComponent("whisper-service")

    if fileManager.fileExists(atPath: downloadedBinary.path) {
        whisperServicePath = supportDir
        executablePath = downloadedBinary
        healthURL = URL(string: "http://127.0.0.1:\(port)/health")!
        return
    }

    // Fallback for development: look for whisper-service directory
    let bundle = Bundle.main

    // Try bundle resources (for legacy packaged .app)
    if let resourcePath = bundle.resourcePath {
        let bundledPath = URL(fileURLWithPath: resourcePath)
            .appendingPathComponent("whisper-service")
        if fileManager.fileExists(atPath: bundledPath.path) {
            whisperServicePath = bundledPath
            let venvPython = bundledPath.appendingPathComponent(".venv/bin/python3")
            if fileManager.fileExists(atPath: venvPython.path) {
                executablePath = venvPython
            } else {
                executablePath = URL(fileURLWithPath: "/usr/bin/python3")
            }
            healthURL = URL(string: "http://127.0.0.1:\(port)/health")!
            return
        }
    }

    // Development fallback
    let devPath = URL(fileURLWithPath: fileManager.currentDirectoryPath)
        .deletingLastPathComponent()
        .appendingPathComponent("whisper-service")
    whisperServicePath = devPath

    let venvPython = devPath.appendingPathComponent(".venv/bin/python3")
    if fileManager.fileExists(atPath: venvPython.path) {
        executablePath = venvPython
    } else {
        executablePath = URL(fileURLWithPath: "/usr/bin/python3")
    }
    healthURL = URL(string: "http://127.0.0.1:\(port)/health")!
}
```

**Step 2: Add executablePath property and update start()**

Add property:
```swift
private let executablePath: URL
```

Update start() to use executablePath appropriately:
- If executablePath is the standalone binary (no .py extension in whisperServicePath), run it directly
- If executablePath is Python, run server.py as before

**Step 3: Build to verify**

Run:
```bash
cd BabbleApp && swift build
```

Expected: Build succeeds

**Step 4: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/ProcessManager.swift
git commit -m "feat: update ProcessManager to use downloaded binary"
```

---

## Task 5: Integrate Download Flow into App Startup

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/AppCoordinator.swift`
- Modify: `BabbleApp/Sources/BabbleApp/AppDelegate.swift`

**Step 1: Add DownloadManager to AppCoordinator**

Add property:
```swift
let downloadManager = DownloadManager()
```

**Step 2: Add download window to AppDelegate**

Add property for download window:
```swift
private var downloadWindow: NSWindow?
```

Add method to show download window:
```swift
private func showDownloadWindow() {
    let downloadView = DownloadView(downloadManager: coordinator.downloadManager) { [weak self] in
        self?.downloadWindow?.close()
        self?.downloadWindow = nil
        self?.finishSetup()
    }

    let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
        styleMask: [.titled, .closable],
        backing: .buffered,
        defer: false
    )
    window.title = "Babble Setup"
    window.contentView = NSHostingView(rootView: downloadView)
    window.center()
    window.makeKeyAndOrderFront(nil)

    downloadWindow = window

    Task {
        try? await coordinator.downloadManager.downloadIfNeeded()
    }
}
```

**Step 3: Update applicationDidFinishLaunching**

Check if download needed before normal setup:
```swift
func applicationDidFinishLaunching(_ notification: Notification) {
    if coordinator.downloadManager.isDownloadNeeded() {
        showDownloadWindow()
    } else {
        finishSetup()
    }
}

private func finishSetup() {
    setupMenuBar()
    setupFloatingPanel()
    checkPermissions()
    coordinator.voiceInputController.start()
}
```

**Step 4: Build and test**

Run:
```bash
cd BabbleApp && swift build
```

Expected: Build succeeds

**Step 5: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/AppCoordinator.swift BabbleApp/Sources/BabbleApp/AppDelegate.swift
git commit -m "feat: integrate download flow into app startup"
```

---

## Task 6: Update build-app.sh

**Files:**
- Modify: `BabbleApp/build-app.sh`

**Step 1: Remove whisper-service bundling**

Update build-app.sh to NOT bundle whisper-service:
```bash
#!/bin/bash
# Build Babble.app bundle (lightweight - downloads whisper-service on first launch)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Build release
echo "Building Swift app..."
swift build -c release

# Create app bundle structure
APP_DIR=".build/Babble.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp .build/release/Babble "$MACOS_DIR/"

# Copy Info.plist
cp Info.plist "$CONTENTS_DIR/"

echo ""
echo "Built Babble.app at $APP_DIR"
echo "Size: $(du -sh "$APP_DIR" | cut -f1)"
echo ""
echo "Note: whisper-service will be downloaded on first launch"
```

**Step 2: Commit**

```bash
git add BabbleApp/build-app.sh
git commit -m "feat: remove whisper-service bundling from build script"
```

---

## Task 7: Add "Loading Model" State to UI

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Models/FloatingPanelState.swift`
- Modify: `BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelView.swift`

**Step 1: Add loadingModel state**

Add new case to FloatingPanelState:
```swift
case loadingModel
```

Add display properties for the new state.

**Step 2: Update FloatingPanelView**

Handle the new state in the view.

**Step 3: Update VoiceInputController**

Set state to .loadingModel when whisper-service is warming up on first transcription.

**Step 4: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Models/FloatingPanelState.swift \
        BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelView.swift \
        BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift
git commit -m "feat: add loading model state for first transcription"
```

---

## Task 8: Test End-to-End Flow

**Step 1: Build PyInstaller binary**

```bash
cd whisper-service && ./build.sh
```

**Step 2: Create test GitHub Release (or simulate locally)**

For local testing, manually copy binary:
```bash
mkdir -p ~/Library/Application\ Support/Babble
cp whisper-service/dist/whisper-service ~/Library/Application\ Support/Babble/
cp whisper-service/dist/whisper-service.sha256 ~/Library/Application\ Support/Babble/
chmod +x ~/Library/Application\ Support/Babble/whisper-service
```

**Step 3: Build and run app**

```bash
cd BabbleApp
swift build -c release
./build-app.sh
open .build/Babble.app
```

**Step 4: Verify flow**

1. App launches and shows download UI (if binary not present)
2. After download/skip, app shows menu bar icon
3. Press Option+Space, record, release
4. First transcription shows "Loading model..." briefly
5. Transcription completes and pastes text

**Step 5: Create final commit**

```bash
git add -A
git commit -m "test: verify end-to-end lightweight distribution flow"
```

---

## Task 9: Create GitHub Release Workflow

**Files:**
- Create: `.github/workflows/build-whisper-service.yml`

**Step 1: Create GitHub Actions workflow**

```yaml
name: Build Whisper Service

on:
  push:
    tags:
      - 'whisper-v*'

jobs:
  build:
    runs-on: macos-14  # Apple Silicon runner

    steps:
      - uses: actions/checkout@v4

      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.11'

      - name: Build with PyInstaller
        run: |
          cd whisper-service
          chmod +x build.sh
          ./build.sh

      - name: Upload Release Assets
        uses: softprops/action-gh-release@v1
        with:
          files: |
            whisper-service/dist/whisper-service
            whisper-service/dist/whisper-service.sha256
```

**Step 2: Commit**

```bash
mkdir -p .github/workflows
git add .github/workflows/build-whisper-service.yml
git commit -m "ci: add GitHub Actions workflow for whisper-service builds"
```

---

## Summary

After completing all tasks:

1. **Initial app size**: ~1 MB (down from ~760 MB)
2. **First launch**: Downloads ~700 MB binary from GitHub Releases
3. **First transcription**: Downloads ~1.5 GB Whisper model (handled by mlx-whisper)
4. **Subsequent use**: Instant startup, fast transcription

**To release:**
1. Merge PR to main
2. Create and push tag: `git tag whisper-v1.0.0 && git push --tags`
3. GitHub Actions builds and uploads binary to Release
4. Build and distribute Babble.app
