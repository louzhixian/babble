# Lightweight Distribution Design

## Overview

Reduce Babble.app initial package size from ~760 MB to ~1 MB by downloading heavy dependencies on first launch.

## Goals

- Initial app package: ~1 MB (down from ~760 MB)
- Seamless first-launch experience with progress indication
- No dependency on system Python installation
- Reliable download with retry and manual fallback

## Architecture

### Package Structure

**Initial Babble.app (~1 MB)**:
```
Babble.app/
├── Contents/
│   ├── MacOS/Babble          ← Swift app with download logic
│   └── Info.plist
```

**After first launch (~700 MB downloaded)**:
```
~/Library/Application Support/Babble/
├── whisper-service           ← PyInstaller standalone binary
└── whisper-service.sha256    ← Integrity checksum
```

**On first transcription (~1.5 GB downloaded)**:
```
~/.cache/huggingface/
└── hub/models--mlx-community--whisper-turbo/
```

### Download Flow

```
App Launch
    ↓
Check ~/Library/Application Support/Babble/whisper-service
    ↓
┌─────────────────┐    ┌─────────────────┐
│ File exists     │    │ File missing    │
│ + valid SHA256  │    │ or corrupted    │
│ → Start service │    │ → Show download │
└─────────────────┘    └─────────────────┘
                              ↓
                       Download from GitHub Releases
                              ↓
                       Verify SHA256
                              ↓
                       Mark executable (chmod +x)
                              ↓
                       Start service
```

## Technical Details

### PyInstaller Packaging

Build whisper-service as standalone binary:

```bash
cd whisper-service
pip install pyinstaller

pyinstaller --onefile \
  --name whisper-service \
  --hidden-import mlx \
  --hidden-import mlx_whisper \
  server.py
```

Output: `dist/whisper-service` (~700 MB standalone executable)

### GitHub Releases

- Tag format: `whisper-v1.0.0`
- Assets per release:
  - `whisper-service` - PyInstaller binary (macOS arm64)
  - `whisper-service.sha256` - SHA256 checksum

Download URL pattern:
```
https://github.com/louzhixian/babble/releases/download/whisper-v{version}/whisper-service
```

### Swift Implementation

**New DownloadManager class**:

```swift
@MainActor
class DownloadManager: ObservableObject {
    @Published var state: DownloadState = .idle
    @Published var progress: Double = 0
    @Published var downloadedSize: Int64 = 0
    @Published var totalSize: Int64 = 0

    private let supportDir: URL
    private let whisperServiceURL: URL
    private let maxRetries = 3

    enum DownloadState {
        case idle
        case checking
        case downloading
        case verifying
        case failed(error: String, retryCount: Int)
        case completed
    }

    func downloadIfNeeded() async throws
    func verifyIntegrity() -> Bool
    func getManualDownloadURL() -> URL
}
```

**ProcessManager changes**:
- Change executable path to `~/Library/Application Support/Babble/whisper-service`
- Call `DownloadManager.downloadIfNeeded()` before starting

**New DownloadView**:
- Shows on first launch when download needed
- Progress bar with percentage and size (e.g., "315 MB / 700 MB")
- Download speed indicator
- On failure: "Retry" button + "Manual download" link

### Error Handling

1. **Download failure**: Retry up to 3 times automatically
2. **After 3 failures**: Show error with:
   - "Retry" button to try again
   - "Manual download" link opening GitHub Releases page
   - Instructions: "Download whisper-service and place in ~/Library/Application Support/Babble/"
3. **SHA256 mismatch**: Treat as corrupted, re-download

### Model Loading

Whisper model download is handled by mlx-whisper library:
- Downloads to `~/.cache/huggingface/` on first transcription
- Show "Loading model for first use..." in UI (no precise progress)
- Subsequent uses: model loads from cache instantly

## User Experience

### First Launch
```
1. Open Babble.app
2. See: "Downloading speech engine..." [=====>    ] 45%
        "315 MB / 700 MB • 2.5 MB/s"
3. Download completes → enters main interface
```

### First Transcription
```
1. Press Option+Space, speak, release
2. See: "Loading model for first use..."
3. Wait ~1-2 minutes for model download + load
4. Transcription appears
```

### Subsequent Use
```
1. Press Option+Space → immediate recording
2. Release → transcription in seconds
```

## File Sizes Summary

| Component | Size | When Downloaded |
|-----------|------|-----------------|
| Initial Babble.app | ~1 MB | App Store / GitHub |
| whisper-service binary | ~700 MB | First app launch |
| Whisper model | ~1.5 GB | First transcription |
| **Total** | **~2.2 GB** | |

## Implementation Tasks

1. Set up PyInstaller build for whisper-service
2. Create GitHub Actions workflow for automated builds
3. Implement DownloadManager in Swift
4. Create DownloadView UI
5. Modify ProcessManager to use new path
6. Update build-app.sh (remove whisper-service bundling)
7. Add "Loading model..." state to UI
8. Test end-to-end flow
