# VTT Build Log
Version: 1.0.0
Date: 2026-06-01

## User Prompt
"yes, build it. just this one time save all output to /Users/josh/Dev/Apps/vtt/buildlog.md. after this run we will go back to using the update files"

## Prior design decisions (from Update00.md)
| Decision | Choice |
|---|---|
| Activation | Toggle hotkey (⌘⇧Space) |
| Model | faster-whisper `small`, int8, language=en |
| Visual | macOS menu bar icon |
| Recording icon | Green mic (🟢🎤) |
| Output | Streaming — type segments as they arrive via VAD pipeline |

## Architecture
- `audio.py` — sounddevice 16kHz mono capture, 480-sample frames (30ms)
- `vad.py` — webrtcvad-based speech boundary detection (ring buffer state machine)
- `transcriber.py` — faster-whisper worker thread, yields segments via callback
- `typer.py` — pynput keyboard injection at active cursor
- `hotkey.py` — pynput GlobalHotKeys, ⌘⇧Space toggle
- `menubar.py` — rumps menu bar app, thread-safe icon updates via @rumps.timer
- `vtt.py` — entry point, wires all components

## VAD choice: webrtcvad (not silero-vad)
- Avoids heavy torch dependency (faster-whisper uses CTranslate2, not torch)
- Sufficient accuracy for clear dictation speech
- Ring buffer pattern: 75% voiced frames → start, 75% silent frames → end

---

## Build Output

