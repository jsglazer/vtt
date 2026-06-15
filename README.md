# VTT — Voice to Text at Cursor

[![GitHub release](https://img.shields.io/github/v/release/jsglazer/vtt?logo=github)](https://github.com/jsglazer/vtt/releases)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?logo=swift&logoColor=white)](https://swift.org)
[![GitHub license](https://img.shields.io/github/license/jsglazer/vtt)](https://github.com/jsglazer/vtt/blob/main/LICENSE)
[![Made with Claude](https://img.shields.io/badge/Made_with-Claude-D97756?logo=anthropic)](https://claude.ai)

A macOS menu bar app that transcribes your voice and types the text wherever your cursor is. Press a hotkey to start speaking; words appear at the cursor as each segment is recognized.

Built in Swift using [WhisperKit](https://github.com/argmaxinc/WhisperKit) — Apple Silicon native, CoreML/ANE optimized, fully offline.

## Features

- **Types at cursor** — works in any app (editors, browsers, notes, chat); uses the Accessibility API directly, with clipboard + ⌘V fallback for apps like Sublime Text that don't expose a writable AX text attribute
- **Menu bar only** — no Dock icon; shows idle / recording / transcribing state via SF Symbol icon
- **Global hotkey** — `⌘⇧Space` toggles recording from any app
- **WhisperKit `large-v2`** — top-tier Whisper model, CoreML-accelerated on Apple Neural Engine
- **Energy VAD with pre-roll** — RMS-based voice activity detection with a 0.5 s pre-roll buffer so the first syllable of each utterance is never clipped
- **Spoken punctuation** — say punctuation words and they are converted to symbols (see table below)
- **Auto-punctuation stripped** — Whisper's automatically inserted commas and terminal punctuation are removed
- **Auto New Line** — optional: inserts a blank line after a configurable period of silence while recording
- **Settings panel** — `⌘,` opens a panel to tune sensitivity, silence timeout, min speech duration, and auto new line without touching code
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

### Hotkeys

| Hotkey | Action |
|---|---|
| `⌘ ⇧ Space` | Toggle recording on/off |
| `⌘ ,` | Open Settings |

### Spoken punctuation

Say these words while dictating and they are replaced with the corresponding symbol:

| Say | Inserts |
|---|---|
| period / full stop | . |
| comma | , |
| question mark | ? |
| exclamation mark / exclamation point | ! |
| colon | : |
| semicolon | ; |
| dash | — |
| hyphen | - |
| ellipsis / dot dot dot | … |
| open paren / open parenthesis | ( |
| close paren / close parenthesis | ) |

All other words are typed literally, including "new line" and "new paragraph".

### Settings

Open **Settings…** from the menu bar (`⌘,`) to adjust:

| Setting | Default | Description |
|---|---|---|
| Microphone Sensitivity | Medium (0.02) | How loud audio must be to trigger recording; increase to ignore background noise |
| Silence Timeout | 0.40 s | How long silence must persist before the current utterance is sent for transcription |
| Min Speech Duration | 0.50 s | Utterances shorter than this are discarded (filters out clicks and brief noise) |
| Auto New Line | Off | When enabled, inserts a blank line after the configured delay of silence while recording; also appends a period if the last typed character was not sentence-ending punctuation |
| Auto New Line Delay | 2.0 s | How long silence must last (while recording) to trigger an automatic blank line |

Click **Restore Defaults** to reset all sliders. Changes take effect immediately without restarting.

### First run

The `large-v2` CoreML model (~3 GB) is downloaded automatically on first launch to `~/Documents/huggingface/models/openai/openai_whisper-large-v2/`. This takes a few minutes depending on connection speed. Watch the console for `VTT: model ready` before starting a recording session.

## Architecture

```
⌘⇧Space (Carbon RegisterEventHotKey)
  └── HotkeyManager           toggle callback → main thread
        └── VTTController
              ├── AudioCapture        AVAudioEngine → AVAudioConverter → 16 kHz mono
              │     └── VAD           RMS energy gating + 0.5 s pre-roll buffer
              │           └── Transcriber    WhisperKit large-v2 (CoreML/ANE)
              │                 │            spoken-punct substitution
              │                 └── Typer    AX kAXSelectedTextAttribute insertion
              │                             (clipboard + ⌘V fallback)
              ├── StatusBarController    NSStatusItem + SF Symbol icons
              └── SettingsWindowController   NSPanel + SwiftUI SettingsView
```

### Source files

| File | Purpose |
|---|---|
| `main.swift` | Manual `NSApplication` wiring (no `@main`, no storyboard) |
| `AppDelegate.swift` | App lifecycle; AX trust check; kicks off async model load |
| `VTTController.swift` | Orchestrates all components, owns recording state and auto-new-line timer |
| `StatusBarController.swift` | `NSStatusItem` menu bar, SF Symbol icons, Start/Stop/Settings menu |
| `HotkeyManager.swift` | Carbon `RegisterEventHotKey` for `⌘⇧Space` |
| `AudioCapture.swift` | `AVAudioEngine` tap + `AVAudioConverter` to 16 kHz mono float32 |
| `VAD.swift` | RMS energy VAD with pre-roll; emits speech segments to Transcriber |
| `Transcriber.swift` | WhisperKit wrapper; strips noise tokens, auto-punctuation; applies spoken-punct table |
| `Typer.swift` | Inserts text via AX API; falls back to clipboard + `⌘V` |
| `SettingsView.swift` | SwiftUI settings form; persists values via `@AppStorage` |
| `SettingsWindowController.swift` | `NSPanel` hosting the SwiftUI settings view |

## Troubleshooting

**Hotkey does nothing / text not inserted**
The most common cause is a stale Accessibility permission after a rebuild. Check the console for `VTT: accessibility trusted = false` and re-add VTT to **System Settings → Privacy & Security → Accessibility**.

**No audio captured**
Grant Microphone permission in **System Settings → Privacy & Security → Microphone**.

**`VTT: model still loading, please wait`**
The WhisperKit model takes several seconds to initialize on first launch (longer while downloading). Wait for `VTT: model ready` before recording.

**Model download fails**
The app pre-creates `~/Documents/huggingface/models/openai/openai_whisper-large-v2/` on launch. If the download still fails, check that the app has permission to write to your Documents folder (**System Settings → Privacy & Security → Files and Folders**).

**VAD triggers on ambient noise**
Open **Settings** and move the Microphone Sensitivity slider toward "Less sensitive".

**VAD cuts speech off too early**
Open **Settings** and increase the Silence Timeout slider.

**First syllable is clipped**
This should not happen — the VAD uses a 0.5 s pre-roll buffer. If it persists, try reducing the Microphone Sensitivity so the VAD opens earlier.

## License

MIT
