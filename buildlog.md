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

### Files created
| File | Purpose |
|---|---|
| `vtt.py` | Entry point, wires all components, runs rumps main loop |
| `audio.py` | sounddevice 16kHz/mono capture, 480-sample frames, queue-based |
| `vad.py` | webrtcvad ring-buffer state machine (75% voiced→start, 75% silent→end) |
| `transcriber.py` | faster-whisper worker thread, `small/int8/en`, segments via callback |
| `typer.py` | pynput keyboard injection at active cursor |
| `hotkey.py` | pynput GlobalHotKeys, ⌘⇧Space toggle |
| `menubar.py` | rumps app, thread-safe icon via @rumps.timer(0.1) |
| `requirements.txt` | All dependencies pinned with minimums |

### Dependency fix
- `webrtcvad 2.0.10` uses `pkg_resources` (removed from Python 3.13 venvs)
- Patched `.venv/lib/python3.13/site-packages/webrtcvad.py` to use `importlib.metadata` instead

### Status
- ✅ All imports verified clean
- ✅ Committed and pushed to github.com/jsglazer/vtt

### First run notes
- faster-whisper downloads `small` model (~500MB) to `~/.cache/huggingface/hub/` on first transcription
- macOS will prompt for **Microphone** and **Accessibility** permissions on first run
- Accessibility permission required for both global hotkey detection and keyboard injection
