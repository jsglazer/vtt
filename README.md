# VTT — Voice to Text at Cursor

A macOS menu bar app that transcribes your voice and types the text wherever your cursor is. Press a hotkey to start speaking; words appear at the cursor as each segment is recognized.

Built in Swift using [WhisperKit](https://github.com/argmaxinc/WhisperKit) — Apple Silicon native, CoreML/ANE optimized, fully offline.

## Features

- **Types at cursor** — works in any app that supports text input (editors, browsers, notes, chat)
- **Menu bar only** — no Dock icon; shows idle / recording / transcribing state via SF Symbol icon
- **Global hotkey** — `⌘⇧Space` toggles recording from any app
- **WhisperKit `large-v2`** — top-tier Whisper model, CoreML-accelerated on Apple Neural Engine
- **Energy VAD with pre-roll** — RMS-based voice activity detection with a 0.5 s pre-roll buffer so the first syllable of each utterance is never clipped
- **Auto-punctuation stripped** — Whisper's inserted commas and terminal punctuation are removed; output is plain dictated text
- **Fully offline** — model runs locally after initial download; no audio leaves the device

## Requirements

- macOS 26 (Tahoe) or later
- Apple Silicon (M1 or later)
- Xcode 26 to build
- ~3 GB disk space for the WhisperKit `large-v2` CoreML model (downloaded on first run)

## Installation

1. Clone the repo and open the Xcode project:

```bash
git clone https://github.com/jsglazer/vtt.git
cd vtt
open VTT/VTT.xcodeproj
```

2. In Xcode press **⌘R** to build and run.

## Permissions

macOS requires two permissions. Both are granted via **System Settings → Privacy & Security**.

| Permission | Why |
|---|---|
| **Microphone** | Audio capture |
| **Accessibility** | Global hotkey (`⌘⇧Space`) and typing text at the cursor |

> **Important:** Every time you rebuild in Xcode the app binary changes and the Accessibility entry becomes stale. After each build, open **System Settings → Privacy & Security → Accessibility**, remove the old VTT entry, and re-add the freshly built binary via **Product → Show Build Folder in Finder → Products → Debug → VTT.app**. The console will print `VTT: accessibility trusted = false` if this step is needed.

## Usage

Click the menu bar icon or press `⌘⇧Space` to start recording. Speak naturally. Press `⌘⇧Space` again (or click **Stop Recording**) when done. The transcribed text is inserted at the cursor position in whatever app is focused.

### Menu bar icons

| Icon | Meaning |
|---|---|
| Microphone outline | Idle — ready to record |
| Microphone filled (green) | Recording — listening for speech |
| Speech bubble with ellipsis | Transcribing — inserting recognized text |

### Hotkey

| Hotkey | Action |
|---|---|
| `⌘ ⇧ Space` | Toggle recording on/off |

### First run

The `large-v2` CoreML model (~3 GB) is downloaded automatically on first launch to `~/Documents/huggingface/models/openai/openai_whisper-large-v2/`. This takes a few minutes depending on connection speed. Watch the console for `VTT: model ready` before starting a recording session.

## Architecture

```
⌘⇧Space (Carbon RegisterEventHotKey)
  └── HotkeyManager        toggle callback → main thread
        └── VTTController
              ├── AudioCapture     AVAudioEngine → AVAudioConverter → 16 kHz mono
              │     └── VAD        RMS energy gating + 0.5 s pre-roll buffer
              │           └── Transcriber    WhisperKit large-v2 (CoreML/ANE)
              │                 └── Typer    AX kAXSelectedTextAttribute insertion
              │                             (clipboard + ⌘V fallback)
              └── StatusBarController    NSStatusItem + SF Symbol icons
```

### Source files

| File | Purpose |
|---|---|
| `main.swift` | Manual `NSApplication` wiring (no `@main`, no storyboard) |
| `AppDelegate.swift` | App lifecycle; AX trust check; kicks off async model load |
| `VTTController.swift` | Orchestrates all components, owns recording state |
| `StatusBarController.swift` | `NSStatusItem` menu bar, SF Symbol icons, Start/Stop menu |
| `HotkeyManager.swift` | Carbon `RegisterEventHotKey` for `⌘⇧Space` |
| `AudioCapture.swift` | `AVAudioEngine` tap + `AVAudioConverter` to 16 kHz mono float32 |
| `VAD.swift` | RMS energy VAD with pre-roll; emits speech segments to Transcriber |
| `Transcriber.swift` | WhisperKit wrapper; strips noise tokens and auto-punctuation |
| `Typer.swift` | Inserts text via AX API; falls back to clipboard + `⌘V` |

## Configuration

| File | Constant | Default | Description |
|---|---|---|---|
| `Transcriber.swift` | `modelName` | `openai_whisper-large-v2` | WhisperKit model name |
| `VAD.swift` | `speechThreshold` | `0.02` | RMS level required to open a speech segment |
| `VAD.swift` | `minSpeechSamples` | `16000` | Minimum samples before a segment can close (~1 s) |
| `VAD.swift` | `silenceSamples` | `9600` | Silence needed to close an utterance (~0.6 s) |
| `VAD.swift` | `prerollCapacity` | `8000` | Pre-roll buffer size (~0.5 s) |

## Troubleshooting

**Hotkey does nothing / text not inserted**
The most common cause is a stale Accessibility permission after a rebuild. Check the console for `VTT: accessibility trusted = false` and re-add VTT to **System Settings → Privacy & Security → Accessibility**.

**No audio captured**
Grant Microphone permission in **System Settings → Privacy & Security → Microphone**.

**`VTT: model still loading, please wait`**
The WhisperKit model takes several seconds to initialize on first launch (longer while downloading). Wait for `VTT: model ready` before recording.

**Model download fails**
The app pre-creates `~/Documents/huggingface/models/openai/openai_whisper-large-v2/` on launch. If the download still fails, check that the app has permission to write to your Documents folder (System Settings → Privacy & Security → Files and Folders).

**VAD cuts speech off too early**
Increase `silenceSamples` in `VAD.swift` (e.g. `12800` for ~0.8 s of silence tolerance).

**VAD triggers on ambient noise**
Increase `speechThreshold` in `VAD.swift` (e.g. `0.03`).

## License

MIT
