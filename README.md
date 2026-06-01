# VTT — Voice to Text at Cursor

A macOS menu bar app that transcribes your voice and types the text wherever your cursor is. Press a hotkey to start speaking; words appear at the cursor as you talk.

Built in Swift using [WhisperKit](https://github.com/argmaxinc/WhisperKit) — Apple Silicon native, CoreML/ANE optimized, fully offline.

## Features

- **Streaming output** — text appears progressively as speech segments are recognized
- **Types at cursor** — works in any app: editors, browsers, terminals, chat
- **Menu bar icon** — shows idle / recording / transcribing state without a Dock presence
- **WhisperKit** — CoreML-accelerated Whisper `small.en` model, optimized for Apple Neural Engine
- **Energy VAD** — simple RMS-based voice activity detection gates transcription cleanly

## Requirements

- macOS 13+
- Apple Silicon Mac (M1 or later) recommended
- Xcode command-line tools or Xcode (for `swift build`)
- ~250 MB disk space for the WhisperKit CoreML model (downloaded on first run)

## Installation

```bash
git clone https://github.com/jsglazer/vtt.git
cd vtt
swift build -c release
```

## Usage

```bash
.build/release/VTT
```

The app starts silently in the macOS menu bar as `🎤`.

| Hotkey | Action |
|---|---|
| `⌘ ⇧ Space` | Toggle recording on/off |

### Status icons

| Icon | Meaning |
|---|---|
| `🎤` | Idle — ready to record |
| `🟢🎤` | Recording — listening for speech |
| `💬` | Transcribing — typing recognized text |

### First run

macOS will prompt for two permissions:

1. **Microphone** — required for audio capture
2. **Accessibility** — required for the global hotkey (`⌘⇧Space`) and typing at the cursor

Both can be granted via **System Settings → Privacy & Security**. Restart after granting Accessibility access.

The WhisperKit `small.en` CoreML model (~250 MB) is downloaded automatically on the first transcription. Subsequent runs use the local cache at `~/Library/Caches/huggingface/`.

> **Tip:** The first hotkey press after launch may feel slow if the model is still loading. Wait for "VTT: model ready" in the console, or just try again in a few seconds.

## Architecture

```
⌘⇧Space (Carbon RegisterEventHotKey)
  └── HotkeyManager      toggle callback → main thread
        └── VTTController
              ├── AudioCapture    AVAudioEngine → resample to 16 kHz mono
              │     └── VAD       RMS energy gating → speech segments
              │           └── Transcriber   WhisperKit small.en (CoreML)
              │                 └── Typer   CGEvent Unicode injection at cursor
              └── StatusBarController   NSStatusItem menu bar
```

### Source files

| File | Purpose |
|---|---|
| `main.swift` | NSApplication setup, `.accessory` policy (no Dock icon) |
| `AppDelegate.swift` | App lifecycle, kicks off async model load |
| `VTTController.swift` | Orchestrates all components, owns recording state |
| `StatusBarController.swift` | `NSStatusItem` menu bar, main-thread-safe updates |
| `HotkeyManager.swift` | Carbon `RegisterEventHotKey` for ⌘⇧Space |
| `AudioCapture.swift` | `AVAudioEngine` tap + `AVAudioConverter` to 16 kHz mono |
| `VAD.swift` | RMS energy VAD — opens on voiced frames, closes on silence |
| `Transcriber.swift` | `WhisperKit` wrapper, background `Task`, English-only |
| `Typer.swift` | `CGEvent` Unicode string injection at active cursor |

## Configuration

Constants at the top of each source file:

| File | Constant | Default | Description |
|---|---|---|---|
| `HotkeyManager.swift` | `kVK_Space` + `cmdKey\|shiftKey` | `⌘⇧Space` | Activation hotkey |
| `Transcriber.swift` | `model:` | `openai_whisper-small.en` | WhisperKit model |
| `VAD.swift` | `speechThreshold` | `0.01` | RMS level to start speech |
| `VAD.swift` | `minSpeechSamples` | `16000` | Min samples before closing (~1 s) |
| `VAD.swift` | `silenceSamples` | `9600` | Silence needed to close utterance (~0.6 s) |

## Troubleshooting

**Hotkey does nothing**
Grant Accessibility permission in **System Settings → Privacy & Security → Accessibility**, then restart.

**No transcription / nothing typed**
Grant Microphone permission in **System Settings → Privacy & Security → Microphone**, then restart.

**"VTT: model still loading"** printed to console
The WhisperKit model takes a few seconds to initialize. Wait for "VTT: model ready" before pressing the hotkey.

**Text appears with leading space**
By design — each recognized segment is prefixed with a space. If you need text at the very start of a field, position the cursor after at least one character first.

**VAD cuts off too early / too late**
Adjust `silenceSamples` and `speechThreshold` in `VAD.swift`. Increase `silenceSamples` for longer pause tolerance; lower `speechThreshold` to be more sensitive.

## License

MIT
