# Babble MVP Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a working voice input tool with MLX Whisper transcription, AFM refinement, and paste-to-input functionality.

**Architecture:** Swift/SwiftUI menu bar app communicates with a local Python FastAPI service for Whisper transcription. AFM calls happen directly in Swift. Audio recording uses AVFoundation, paste uses CGEvent simulation.

**Tech Stack:** Swift 6, SwiftUI, AVFoundation, FoundationModels (AFM), Python 3.10+, FastAPI, mlx-whisper

---

## Phase 1: Whisper Service

### Task 1.1: Project Structure Setup

**Files:**
- Create: `whisper-service/requirements.txt`
- Create: `whisper-service/config.yaml`

**Step 1: Create requirements.txt**

```txt
mlx-whisper>=0.4.0
fastapi>=0.109.0
uvicorn>=0.27.0
python-multipart>=0.0.6
pyyaml>=6.0
```

**Step 2: Create config.yaml**

```yaml
server:
  host: "127.0.0.1"
  port: 8787

model:
  name: "mlx-community/whisper-large-v3-turbo"
  language: "zh"

lifecycle:
  idle_timeout_minutes: 5
```

**Step 3: Commit**

```bash
git add whisper-service/
git commit -m "feat(whisper): add project config files"
```

---

### Task 1.2: Transcription Module

**Files:**
- Create: `whisper-service/transcribe.py`

**Step 1: Create transcribe.py with model loading and transcription**

```python
"""MLX Whisper transcription module."""

import time
from pathlib import Path
from typing import Optional

import mlx_whisper


class Transcriber:
    """Handles MLX Whisper model loading and transcription."""

    def __init__(self, model_name: str = "mlx-community/whisper-large-v3-turbo"):
        self.model_name = model_name
        self._model_loaded = False
        self._last_used: float = 0

    def ensure_loaded(self) -> None:
        """Ensure model is loaded (lazy loading on first use)."""
        if not self._model_loaded:
            # mlx_whisper loads model on first transcribe call
            self._model_loaded = True
        self._last_used = time.time()

    def transcribe(
        self,
        audio_path: Path,
        language: str = "zh",
    ) -> dict:
        """
        Transcribe audio file to text.

        Args:
            audio_path: Path to audio file (wav, m4a, mp3)
            language: Language code for transcription

        Returns:
            dict with keys: text, segments, duration, processing_time
        """
        self.ensure_loaded()

        start_time = time.time()

        result = mlx_whisper.transcribe(
            str(audio_path),
            path_or_hf_repo=self.model_name,
            language=language,
        )

        processing_time = time.time() - start_time

        return {
            "text": result.get("text", "").strip(),
            "segments": result.get("segments", []),
            "language": result.get("language", language),
            "processing_time": round(processing_time, 3),
        }

    @property
    def idle_seconds(self) -> float:
        """Seconds since last use."""
        if self._last_used == 0:
            return 0
        return time.time() - self._last_used

    def unload(self) -> None:
        """Unload model to free memory."""
        # mlx_whisper doesn't have explicit unload, but we can reset state
        self._model_loaded = False
        self._last_used = 0


# Global instance
_transcriber: Optional[Transcriber] = None


def get_transcriber(model_name: str = "mlx-community/whisper-large-v3-turbo") -> Transcriber:
    """Get or create global transcriber instance."""
    global _transcriber
    if _transcriber is None:
        _transcriber = Transcriber(model_name)
    return _transcriber
```

**Step 2: Commit**

```bash
git add whisper-service/transcribe.py
git commit -m "feat(whisper): add transcription module"
```

---

### Task 1.3: FastAPI Server

**Files:**
- Create: `whisper-service/server.py`

**Step 1: Create server.py with health and transcribe endpoints**

```python
"""FastAPI server for Whisper transcription service."""

import tempfile
from pathlib import Path

import yaml
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.responses import JSONResponse

from transcribe import get_transcriber

# Load config
config_path = Path(__file__).parent / "config.yaml"
with open(config_path) as f:
    config = yaml.safe_load(f)

app = FastAPI(title="Babble Whisper Service")

# Initialize transcriber with configured model
transcriber = get_transcriber(config["model"]["name"])


@app.get("/health")
async def health_check():
    """Health check endpoint."""
    return {
        "status": "ready",
        "model": config["model"]["name"],
    }


@app.post("/transcribe")
async def transcribe_audio(
    audio: UploadFile = File(...),
    language: str = Form(default=None),
):
    """
    Transcribe uploaded audio file.

    Args:
        audio: Audio file (wav, m4a, mp3, etc.)
        language: Optional language code (default from config)

    Returns:
        JSON with transcription result
    """
    # Use configured language if not specified
    lang = language or config["model"]["language"]

    # Validate file type
    allowed_extensions = {".wav", ".m4a", ".mp3", ".flac", ".ogg"}
    file_ext = Path(audio.filename or "").suffix.lower()
    if file_ext not in allowed_extensions:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {file_ext}. Allowed: {allowed_extensions}",
        )

    # Save to temp file
    with tempfile.NamedTemporaryFile(suffix=file_ext, delete=False) as tmp:
        content = await audio.read()
        tmp.write(content)
        tmp_path = Path(tmp.name)

    try:
        result = transcriber.transcribe(tmp_path, language=lang)
        return JSONResponse(content=result)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Clean up temp file
        tmp_path.unlink(missing_ok=True)


def main():
    """Run the server."""
    import uvicorn

    uvicorn.run(
        app,
        host=config["server"]["host"],
        port=config["server"]["port"],
        log_level="info",
    )


if __name__ == "__main__":
    main()
```

**Step 2: Commit**

```bash
git add whisper-service/server.py
git commit -m "feat(whisper): add FastAPI server with transcribe endpoint"
```

---

### Task 1.4: Test Whisper Service Manually

**Step 1: Create virtual environment and install dependencies**

```bash
cd whisper-service
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

**Step 2: Start server**

```bash
python server.py
```

**Step 3: Test health endpoint (in another terminal)**

```bash
curl http://127.0.0.1:8787/health
```

Expected: `{"status":"ready","model":"mlx-community/whisper-large-v3-turbo"}`

**Step 4: Test transcribe with a sample audio file (if available)**

```bash
curl -X POST http://127.0.0.1:8787/transcribe \
  -F "audio=@test.wav" \
  -F "language=zh"
```

**Step 5: Stop server and commit .venv to gitignore**

```bash
echo ".venv/" >> .gitignore
git add .gitignore
git commit -m "chore(whisper): add .venv to gitignore"
```

---

## Phase 2: Swift App Foundation

### Task 2.1: Create Xcode Project

**Files:**
- Create: `BabbleApp/` Xcode project

**Step 1: Create Swift Package / Xcode project structure**

Use Xcode or swift package init to create:

```
BabbleApp/
├── Package.swift (if using SPM) or BabbleApp.xcodeproj
├── Sources/
│   └── BabbleApp/
│       ├── BabbleApp.swift
│       └── AppDelegate.swift
└── Resources/
```

For a menu bar app, we need an AppDelegate-based lifecycle.

**Step 2: Create BabbleApp.swift**

```swift
// BabbleApp/Sources/BabbleApp/BabbleApp.swift

import SwiftUI

@main
struct BabbleApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

**Step 3: Create AppDelegate.swift**

```swift
// BabbleApp/Sources/BabbleApp/AppDelegate.swift

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Babble")
            button.action = #selector(togglePopover)
            button.target = self
        }

        // Create menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(startRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func togglePopover() {
        // Will implement floating panel later
    }

    @objc private func startRecording() {
        print("Recording started...")
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

**Step 4: Commit**

```bash
git add BabbleApp/
git commit -m "feat(app): create Swift app with menu bar"
```

---

### Task 2.2: Audio Recording Service

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/AudioRecorder.swift`

**Step 1: Create AudioRecorder.swift**

```swift
// BabbleApp/Sources/BabbleApp/Services/AudioRecorder.swift

import AVFoundation
import Foundation

enum RecordingState {
    case idle
    case recording
    case processing
}

@MainActor
class AudioRecorder: ObservableObject {
    @Published var state: RecordingState = .idle
    @Published var audioLevel: Float = 0

    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private var recordingURL: URL?

    var isRecording: Bool {
        state == .recording
    }

    func startRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.isMeteringEnabled = true
        audioRecorder?.record()

        recordingURL = url
        state = .recording

        // Start level monitoring
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAudioLevel()
            }
        }
    }

    func stopRecording() -> URL? {
        levelTimer?.invalidate()
        levelTimer = nil

        audioRecorder?.stop()
        audioRecorder = nil

        state = .processing

        let url = recordingURL
        recordingURL = nil
        return url
    }

    func reset() {
        state = .idle
        audioLevel = 0
    }

    private func updateAudioLevel() {
        guard let recorder = audioRecorder else { return }
        recorder.updateMeters()
        let level = recorder.averagePower(forChannel: 0)
        // Convert dB to 0-1 range
        audioLevel = max(0, min(1, (level + 60) / 60))
    }
}
```

**Step 2: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/AudioRecorder.swift
git commit -m "feat(app): add audio recording service"
```

---

### Task 2.3: Whisper HTTP Client

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/WhisperClient.swift`

**Step 1: Create WhisperClient.swift**

```swift
// BabbleApp/Sources/BabbleApp/Services/WhisperClient.swift

import Foundation

struct TranscriptionResult: Codable {
    let text: String
    let segments: [Segment]?
    let language: String?
    let processingTime: Double?

    enum CodingKeys: String, CodingKey {
        case text
        case segments
        case language
        case processingTime = "processing_time"
    }

    struct Segment: Codable {
        let start: Double?
        let end: Double?
        let text: String?
    }
}

struct HealthResponse: Codable {
    let status: String
    let model: String
}

enum WhisperClientError: Error, LocalizedError {
    case serverNotRunning
    case invalidResponse
    case transcriptionFailed(String)

    var errorDescription: String? {
        switch self {
        case .serverNotRunning:
            return "Whisper service is not running"
        case .invalidResponse:
            return "Invalid response from Whisper service"
        case .transcriptionFailed(let message):
            return "Transcription failed: \(message)"
        }
    }
}

actor WhisperClient {
    private let baseURL: URL
    private let session: URLSession

    init(host: String = "127.0.0.1", port: Int = 8787) {
        self.baseURL = URL(string: "http://\(host):\(port)")!
        self.session = URLSession.shared
    }

    func checkHealth() async throws -> HealthResponse {
        let url = baseURL.appendingPathComponent("health")
        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WhisperClientError.serverNotRunning
        }

        return try JSONDecoder().decode(HealthResponse.self, from: data)
    }

    func transcribe(audioURL: URL, language: String = "zh") async throws -> TranscriptionResult {
        let url = baseURL.appendingPathComponent("transcribe")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()

        // Add audio file
        let audioData = try Data(contentsOf: audioURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)

        // Add language
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"language\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(language)\r\n".data(using: .utf8)!)

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw WhisperClientError.invalidResponse
        }

        if httpResponse.statusCode != 200 {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw WhisperClientError.transcriptionFailed(errorMessage)
        }

        return try JSONDecoder().decode(TranscriptionResult.self, from: data)
    }
}
```

**Step 2: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/WhisperClient.swift
git commit -m "feat(app): add Whisper HTTP client"
```

---

### Task 2.4: AFM Refine Service

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/RefineService.swift`

**Step 1: Create RefineService.swift**

```swift
// BabbleApp/Sources/BabbleApp/Services/RefineService.swift

import Foundation
import FoundationModels

enum RefineMode: String, CaseIterable {
    case off = "关闭"
    case correct = "纠错"
    case punctuate = "标点"
    case polish = "润色"

    var prompt: String? {
        switch self {
        case .off:
            return nil
        case .correct:
            return "修正以下语音转写中的明显错误，保持原意和口吻，只输出修正后的文本："
        case .punctuate:
            return "修正以下语音转写中的错误并优化标点符号，保持原意，只输出修正后的文本："
        case .polish:
            return "将以下口语转写转为通顺的书面表达，保持原意，只输出修正后的文本："
        }
    }
}

enum RefineError: Error, LocalizedError {
    case modelNotAvailable
    case refineFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelNotAvailable:
            return "Apple Foundation Model is not available on this device"
        case .refineFailed(let message):
            return "Refinement failed: \(message)"
        }
    }
}

actor RefineService {
    private var session: LanguageModelSession?

    func refine(text: String, mode: RefineMode) async throws -> String {
        // If mode is off, return original text
        guard let prompt = mode.prompt else {
            return text
        }

        // Check availability
        guard LanguageModel.isAvailable else {
            throw RefineError.modelNotAvailable
        }

        // Create session if needed
        if session == nil {
            session = LanguageModelSession()
        }

        guard let session = session else {
            throw RefineError.modelNotAvailable
        }

        let fullPrompt = "\(prompt)\n\n\(text)"

        do {
            let response = try await session.respond(to: fullPrompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            throw RefineError.refineFailed(error.localizedDescription)
        }
    }

    func checkAvailability() -> Bool {
        return LanguageModel.isAvailable
    }
}
```

**Step 2: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/RefineService.swift
git commit -m "feat(app): add AFM refine service"
```

---

### Task 2.5: Paste Service

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/PasteService.swift`

**Step 1: Create PasteService.swift**

```swift
// BabbleApp/Sources/BabbleApp/Services/PasteService.swift

import AppKit
import Carbon.HIToolbox

enum PasteError: Error, LocalizedError {
    case accessibilityNotGranted
    case pasteFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotGranted:
            return "Accessibility permission is required to simulate paste"
        case .pasteFailed:
            return "Failed to simulate paste keystroke"
        }
    }
}

struct PasteService {
    /// Copy text to clipboard and simulate Cmd+V paste
    static func pasteText(_ text: String) throws {
        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Simulate Cmd+V
        try simulatePaste()
    }

    /// Copy text to clipboard only (no paste simulation)
    static func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func simulatePaste() throws {
        // Check accessibility permission
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        guard AXIsProcessTrustedWithOptions(options as CFDictionary) else {
            throw PasteError.accessibilityNotGranted
        }

        // Create Cmd+V key event
        let source = CGEventSource(stateID: .hidSystemState)

        // Key down
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true) else {
            throw PasteError.pasteFailed
        }
        keyDown.flags = .maskCommand

        // Key up
        guard let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false) else {
            throw PasteError.pasteFailed
        }
        keyUp.flags = .maskCommand

        // Post events
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Check if accessibility permission is granted
    static func checkAccessibility(prompt: Bool = false) -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
```

**Step 2: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/PasteService.swift
git commit -m "feat(app): add paste service with clipboard and Cmd+V simulation"
```

---

## Phase 3: Core Flow Integration

### Task 3.1: Hotkey Manager

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/HotkeyManager.swift`

**Step 1: Create HotkeyManager.swift**

```swift
// BabbleApp/Sources/BabbleApp/Services/HotkeyManager.swift

import AppKit
import Carbon.HIToolbox

enum HotkeyEvent {
    case shortPress    // Toggle mode: tap to start/stop
    case longPressStart  // Push-to-talk: held down
    case longPressEnd    // Push-to-talk: released
}

@MainActor
class HotkeyManager: ObservableObject {
    typealias HotkeyHandler = (HotkeyEvent) -> Void

    private var eventMonitor: Any?
    private var keyDownTime: Date?
    private var isKeyDown = false
    private var handler: HotkeyHandler?

    // Long press threshold in seconds
    private let longPressThreshold: TimeInterval = 0.3

    // Default hotkey: Option + Space
    private let hotkeyKeyCode: UInt16 = UInt16(kVK_Space)
    private let hotkeyModifiers: NSEvent.ModifierFlags = .option

    func register(handler: @escaping HotkeyHandler) {
        self.handler = handler

        // Monitor key events globally
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            Task { @MainActor in
                self?.handleEvent(event)
            }
        }
    }

    func unregister() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        handler = nil
    }

    private func handleEvent(_ event: NSEvent) {
        // Check if it's our hotkey
        guard event.keyCode == hotkeyKeyCode else { return }

        switch event.type {
        case .keyDown:
            guard !isKeyDown else { return } // Ignore key repeat
            guard event.modifierFlags.contains(hotkeyModifiers) else { return }

            isKeyDown = true
            keyDownTime = Date()

        case .keyUp:
            guard isKeyDown else { return }
            isKeyDown = false

            guard let downTime = keyDownTime else { return }
            let duration = Date().timeIntervalSince(downTime)
            keyDownTime = nil

            if duration < longPressThreshold {
                // Short press - toggle mode
                handler?(.shortPress)
            } else {
                // Long press released
                handler?(.longPressEnd)
            }

        default:
            break
        }

        // Check for long press start
        if isKeyDown, let downTime = keyDownTime {
            let duration = Date().timeIntervalSince(downTime)
            if duration >= longPressThreshold {
                handler?(.longPressStart)
                keyDownTime = nil // Prevent multiple triggers
            }
        }
    }
}
```

**Step 2: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/HotkeyManager.swift
git commit -m "feat(app): add hotkey manager with long/short press detection"
```

---

### Task 3.2: Voice Input Controller

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift`

**Step 1: Create VoiceInputController.swift - the main orchestrator**

```swift
// BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift

import Foundation
import SwiftUI

enum VoiceInputState {
    case idle
    case recording
    case transcribing
    case refining
    case completed(String)
    case error(String)
}

@MainActor
class VoiceInputController: ObservableObject {
    @Published var state: VoiceInputState = .idle
    @Published var audioLevel: Float = 0
    @Published var refineMode: RefineMode = .punctuate

    private let audioRecorder = AudioRecorder()
    private let whisperClient = WhisperClient()
    private let refineService = RefineService()
    private let hotkeyManager = HotkeyManager()

    private var isToggleRecording = false  // For toggle mode

    init() {
        // Observe audio level from recorder
        audioRecorder.$audioLevel
            .assign(to: &$audioLevel)
    }

    func start() {
        hotkeyManager.register { [weak self] event in
            Task { @MainActor in
                self?.handleHotkeyEvent(event)
            }
        }
    }

    func stop() {
        hotkeyManager.unregister()
    }

    private func handleHotkeyEvent(_ event: HotkeyEvent) {
        switch event {
        case .shortPress:
            // Toggle mode
            if case .recording = state {
                stopAndProcess()
            } else if case .idle = state {
                startRecording()
                isToggleRecording = true
            }

        case .longPressStart:
            // Push-to-talk start
            if case .idle = state {
                startRecording()
                isToggleRecording = false
            }

        case .longPressEnd:
            // Push-to-talk end
            if case .recording = state, !isToggleRecording {
                stopAndProcess()
            }
        }
    }

    private func startRecording() {
        do {
            try audioRecorder.startRecording()
            state = .recording
        } catch {
            state = .error("Failed to start recording: \(error.localizedDescription)")
        }
    }

    private func stopAndProcess() {
        guard let audioURL = audioRecorder.stopRecording() else {
            state = .error("No audio recorded")
            return
        }

        Task {
            await processAudio(at: audioURL)
        }
    }

    private func processAudio(at url: URL) async {
        state = .transcribing

        do {
            // Transcribe
            let result = try await whisperClient.transcribe(audioURL: url)

            guard !result.text.isEmpty else {
                state = .error("No speech detected")
                return
            }

            // Refine
            state = .refining
            let refinedText = try await refineService.refine(text: result.text, mode: refineMode)

            // Paste
            try PasteService.pasteText(refinedText)

            state = .completed(refinedText)

            // Reset after a short delay
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            state = .idle

        } catch {
            state = .error(error.localizedDescription)
        }

        // Clean up audio file
        try? FileManager.default.removeItem(at: url)
    }

    func reset() {
        audioRecorder.reset()
        state = .idle
    }
}
```

**Step 2: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift
git commit -m "feat(app): add voice input controller orchestrating the full flow"
```

---

### Task 3.3: Floating Panel UI

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelView.swift`
- Create: `BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelWindow.swift`

**Step 1: Create FloatingPanelView.swift**

```swift
// BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelView.swift

import SwiftUI

struct FloatingPanelView: View {
    @ObservedObject var controller: VoiceInputController

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            statusIcon
                .font(.title2)

            // Status text and audio level
            VStack(alignment: .leading, spacing: 4) {
                Text(statusText)
                    .font(.headline)

                if case .recording = controller.state {
                    AudioLevelView(level: controller.audioLevel)
                        .frame(height: 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 8)
    }

    private var statusIcon: some View {
        Group {
            switch controller.state {
            case .idle:
                Image(systemName: "mic")
                    .foregroundColor(.secondary)
            case .recording:
                Image(systemName: "mic.fill")
                    .foregroundColor(.red)
            case .transcribing:
                Image(systemName: "waveform")
                    .foregroundColor(.blue)
            case .refining:
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
            }
        }
    }

    private var statusText: String {
        switch controller.state {
        case .idle:
            return "Ready"
        case .recording:
            return "Recording..."
        case .transcribing:
            return "Transcribing..."
        case .refining:
            return "Refining..."
        case .completed(let text):
            return String(text.prefix(30)) + (text.count > 30 ? "..." : "")
        case .error(let message):
            return message
        }
    }
}

struct AudioLevelView: View {
    let level: Float

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.gray.opacity(0.3))

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(width: geometry.size.width * CGFloat(level))
            }
        }
    }
}
```

**Step 2: Create FloatingPanelWindow.swift**

```swift
// BabbleApp/Sources/BabbleApp/UI/FloatingPanel/FloatingPanelWindow.swift

import AppKit
import SwiftUI

class FloatingPanelWindow: NSPanel {
    init(controller: VoiceInputController) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 250, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false

        // Position at top center of screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - frame.width / 2
            let y = screenFrame.maxY - frame.height - 50
            setFrameOrigin(NSPoint(x: x, y: y))
        }

        contentView = NSHostingView(rootView: FloatingPanelView(controller: controller))
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
```

**Step 3: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/UI/FloatingPanel/
git commit -m "feat(app): add floating panel UI for status display"
```

---

### Task 3.4: Update AppDelegate to Wire Everything

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/AppDelegate.swift`

**Step 1: Update AppDelegate.swift**

```swift
// BabbleApp/Sources/BabbleApp/AppDelegate.swift

import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanelWindow?
    private let controller = VoiceInputController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupFloatingPanel()
        checkPermissions()
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "Babble")
        }

        let menu = NSMenu()

        // Refine mode submenu
        let refineModeItem = NSMenuItem(title: "Refine Mode", action: nil, keyEquivalent: "")
        let refineModeMenu = NSMenu()
        for mode in RefineMode.allCases {
            let item = NSMenuItem(title: mode.rawValue, action: #selector(setRefineMode(_:)), keyEquivalent: "")
            item.representedObject = mode
            item.state = controller.refineMode == mode ? .on : .off
            refineModeMenu.addItem(item)
        }
        refineModeItem.submenu = refineModeMenu
        menu.addItem(refineModeItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Show Panel", action: #selector(showPanel), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Hide Panel", action: #selector(hidePanel), keyEquivalent: "h"))

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Quit Babble", action: #selector(quit), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    private func setupFloatingPanel() {
        floatingPanel = FloatingPanelWindow(controller: controller)
    }

    private func checkPermissions() {
        // Check microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    self.showPermissionAlert(for: "Microphone")
                }
            }
        }

        // Check accessibility permission
        if !PasteService.checkAccessibility(prompt: true) {
            showPermissionAlert(for: "Accessibility")
        }
    }

    private func showPermissionAlert(for permission: String) {
        let alert = NSAlert()
        alert.messageText = "\(permission) Permission Required"
        alert.informativeText = "Babble needs \(permission) permission to function. Please grant it in System Preferences."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            if permission == "Microphone" {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!)
            } else {
                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
            }
        }
    }

    @objc private func setRefineMode(_ sender: NSMenuItem) {
        guard let mode = sender.representedObject as? RefineMode else { return }
        controller.refineMode = mode

        // Update menu checkmarks
        if let menu = sender.menu {
            for item in menu.items {
                item.state = item.representedObject as? RefineMode == mode ? .on : .off
            }
        }
    }

    @objc private func showPanel() {
        floatingPanel?.orderFront(nil)
    }

    @objc private func hidePanel() {
        floatingPanel?.orderOut(nil)
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
```

**Step 2: Add AVFoundation import at top**

Add `import AVFoundation` to the imports.

**Step 3: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/AppDelegate.swift
git commit -m "feat(app): wire up controller, floating panel, and menu bar"
```

---

## Phase 4: Process Management

### Task 4.1: Whisper Service Process Manager

**Files:**
- Create: `BabbleApp/Sources/BabbleApp/Services/ProcessManager.swift`

**Step 1: Create ProcessManager.swift**

```swift
// BabbleApp/Sources/BabbleApp/Services/ProcessManager.swift

import Foundation

actor WhisperProcessManager {
    private var process: Process?
    private var isRunning = false

    private let whisperServicePath: URL
    private let pythonPath: String

    init() {
        // Locate whisper-service relative to app bundle or development path
        let bundle = Bundle.main
        if let resourcePath = bundle.resourcePath {
            whisperServicePath = URL(fileURLWithPath: resourcePath)
                .appendingPathComponent("whisper-service")
        } else {
            // Development fallback
            whisperServicePath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .deletingLastPathComponent()
                .appendingPathComponent("whisper-service")
        }

        // Find Python
        pythonPath = "/usr/bin/env"
    }

    func start() async throws {
        guard !isRunning else { return }

        let serverPath = whisperServicePath.appendingPathComponent("server.py")

        guard FileManager.default.fileExists(atPath: serverPath.path) else {
            throw ProcessManagerError.serviceNotFound(serverPath.path)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.arguments = ["python3", serverPath.path]
        process.currentDirectoryURL = whisperServicePath

        // Capture output for debugging
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        self.process = process
        isRunning = true

        // Wait a moment for server to start
        try await Task.sleep(nanoseconds: 2_000_000_000)
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    func ensureRunning() async throws {
        if !isRunning {
            try await start()
        }
    }

    var running: Bool {
        isRunning && (process?.isRunning ?? false)
    }
}

enum ProcessManagerError: Error, LocalizedError {
    case serviceNotFound(String)
    case startFailed(String)

    var errorDescription: String? {
        switch self {
        case .serviceNotFound(let path):
            return "Whisper service not found at: \(path)"
        case .startFailed(let message):
            return "Failed to start Whisper service: \(message)"
        }
    }
}
```

**Step 2: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Services/ProcessManager.swift
git commit -m "feat(app): add process manager for whisper service lifecycle"
```

---

### Task 4.2: Integrate Process Manager into Controller

**Files:**
- Modify: `BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift`

**Step 1: Update VoiceInputController to use ProcessManager**

Add process manager and ensure service is running before transcription:

```swift
// Add to VoiceInputController class properties:
private let processManager = WhisperProcessManager()

// Update processAudio method to ensure service is running:
private func processAudio(at url: URL) async {
    state = .transcribing

    do {
        // Ensure Whisper service is running
        try await processManager.ensureRunning()

        // ... rest of the method stays the same
    }
}

// Add cleanup in a new deinit or stop method:
func cleanup() async {
    hotkeyManager.unregister()
    await processManager.stop()
}
```

**Step 2: Commit**

```bash
git add BabbleApp/Sources/BabbleApp/Controllers/VoiceInputController.swift
git commit -m "feat(app): integrate process manager into voice input controller"
```

---

## Phase 5: Build & Test

### Task 5.1: Create Package.swift (if using SPM)

**Files:**
- Create: `BabbleApp/Package.swift`

**Step 1: Create Package.swift**

```swift
// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "BabbleApp",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .executable(name: "Babble", targets: ["BabbleApp"])
    ],
    targets: [
        .executableTarget(
            name: "BabbleApp",
            path: "Sources/BabbleApp"
        )
    ]
)
```

**Step 2: Commit**

```bash
git add BabbleApp/Package.swift
git commit -m "feat(app): add Package.swift for Swift Package Manager"
```

---

### Task 5.2: Create Development Script

**Files:**
- Create: `scripts/dev.sh`

**Step 1: Create dev.sh**

```bash
#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Starting Babble development environment..."

# Start Whisper service in background
echo "Starting Whisper service..."
cd "$PROJECT_DIR/whisper-service"
if [ ! -d ".venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
else
    source .venv/bin/activate
fi

python server.py &
WHISPER_PID=$!
echo "Whisper service started (PID: $WHISPER_PID)"

# Wait for service to be ready
sleep 3

# Build and run Swift app
echo "Building and running Babble app..."
cd "$PROJECT_DIR/BabbleApp"
swift run

# Cleanup
echo "Stopping Whisper service..."
kill $WHISPER_PID 2>/dev/null || true

echo "Done."
```

**Step 2: Make executable and commit**

```bash
chmod +x scripts/dev.sh
git add scripts/dev.sh
git commit -m "feat(scripts): add development runner script"
```

---

### Task 5.3: Final Integration Test

**Step 1: Run the full development stack**

```bash
./scripts/dev.sh
```

**Step 2: Test the flow**
1. App should appear in menu bar
2. Press Option+Space (short press) to start recording
3. Speak something
4. Press Option+Space again to stop
5. Verify text is pasted

**Step 3: If all works, commit any final fixes**

```bash
git add -A
git commit -m "feat: complete MVP with voice input, transcription, and paste"
```

---

## Summary

This plan implements the Babble MVP with:

1. **Whisper Service** (Python/FastAPI) - `/transcribe` and `/health` endpoints
2. **Swift App** - Menu bar presence, floating status panel
3. **Core Services** - AudioRecorder, WhisperClient, RefineService, PasteService
4. **Hotkey Manager** - Option+Space with long/short press detection
5. **Voice Input Controller** - Orchestrates the full flow
6. **Process Manager** - Manages Whisper service lifecycle

Total: ~20 tasks, each 2-5 minutes of focused work.
