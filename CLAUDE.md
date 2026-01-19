# CLAUDE.md

This file provides guidance for Claude Code when working in this repository.

## Project Overview

**Babble** is a macOS 26+ voice input tool that uses:
- **MLX Whisper Turbo** for local speech-to-text transcription
- **Apple Foundation Models (AFM)** for on-device text refinement
- **Clipboard + Cmd+V simulation** for pasting text into any application

## Repository Structure

```
babble/
├── BabbleApp/              # Swift macOS menu bar application
│   ├── Package.swift       # Swift Package Manager config (Swift 6.2, macOS 26+)
│   └── Sources/BabbleApp/
│       ├── BabbleApp.swift           # App entry point (@main)
│       ├── AppDelegate.swift         # Menu bar setup, permissions
│       ├── Controllers/
│       │   └── VoiceInputController.swift  # Core flow orchestration
│       ├── Services/
│       │   ├── AudioRecorder.swift         # AVAudioRecorder wrapper
│       │   ├── WhisperClient.swift         # HTTP client for whisper-service
│       │   ├── RefineService.swift         # AFM integration
│       │   ├── PasteService.swift          # Clipboard + CGEvent paste
│       │   ├── HotkeyManager.swift         # Global Option+Space hotkey
│       │   └── WhisperProcessManager.swift # Python process lifecycle
│       └── Views/
│           └── FloatingPanelWindow.swift   # Status indicator panel
├── whisper-service/        # Python FastAPI backend
│   ├── server.py           # FastAPI app with /health and /transcribe
│   ├── transcribe.py       # MLX Whisper wrapper
│   ├── config.yaml         # Server configuration
│   └── requirements.txt    # Python dependencies
└── docs/plans/             # Design and implementation documents
```

## Build Commands

### Swift App (BabbleApp)

```bash
cd BabbleApp

# Build
swift build

# Build release
swift build -c release

# Run
swift run Babble

# Clean
swift package clean
```

**Requirements:** macOS 26+, Xcode with Swift 6.2+

### Python Service (whisper-service)

```bash
cd whisper-service

# Create virtual environment
python3 -m venv .venv
source .venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run server
python server.py
# or
uvicorn server:app --host 127.0.0.1 --port 8787
```

**Requirements:** Python 3.10+, Apple Silicon Mac (for MLX)

## Architecture

### Data Flow

1. User presses **Option+Space** (short press = toggle, long press = push-to-talk)
2. **AudioRecorder** captures audio to temporary WAV file
3. **WhisperProcessManager** ensures Python service is running
4. **WhisperClient** sends audio via multipart POST to `/transcribe`
5. **RefineService** optionally refines text using Apple Foundation Models
6. **PasteService** copies to clipboard and simulates Cmd+V

### Key Technical Decisions

- **Swift 6.2 strict concurrency**: Uses `@MainActor` on UI classes, `actor` for RefineService
- **FoundationModels framework**: Requires `SystemLanguageModel.default.availability` check
- **Accessibility permission**: Required for CGEvent-based paste simulation
- **Non-activating window**: NSPanel with `.nonactivatingPanel` style for floating indicator

## Refine Modes

| Mode | Chinese | Purpose |
|------|---------|---------|
| off | 关闭 | No refinement, raw transcription |
| correct | 纠错 | Fix obvious transcription errors |
| punctuate | 标点 | Fix errors + optimize punctuation |
| polish | 润色 | Convert spoken text to written form |

## Configuration

### whisper-service/config.yaml

```yaml
server:
  host: "127.0.0.1"
  port: 8787
whisper:
  model: "mlx-community/whisper-turbo"
  language: "zh"
```

## Development Notes

- The Swift app manages the Python service lifecycle automatically
- Whisper model downloads on first use (~1.5GB)
- AFM availability depends on device (Apple Silicon with Neural Engine)
- Git worktrees are used for feature development (see `.worktrees/`)

## Permissions Required

- **Microphone**: For audio recording
- **Accessibility**: For simulating Cmd+V paste keystroke

## PR Workflow

1. **Make changes** and verify build passes (`swift build`)
2. **Update related documentation** if the change affects:
   - Architecture or data flow → update this CLAUDE.md
   - Design decisions → update `docs/plans/` documents
   - Configuration → update relevant config examples
3. **Commit and push** to feature branch
4. **Create PR** with:
   - Summary of changes
   - Test plan checklist
5. **Add Review section** at the bottom of PR description:
   ```markdown
   ## Review

   @codex
   ```
6. Address review feedback, then merge

### Re-requesting Review After Fixes

After addressing review feedback, you need to re-trigger the review:

1. **Commit the fixes** to the same branch
2. **Add a comment** on the PR to request re-review:
   ```markdown
   @codex

   **Changes since last review:**
   - <commit hash 1>: <summary of fix>
   - <commit hash 2>: <summary of fix>
   ```
3. Wait for new review feedback and repeat if needed
