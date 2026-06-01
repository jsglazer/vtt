# VTT — Voice to Text at Cursor

A macOS menu bar app that transcribes your voice and types the text wherever your cursor is. Press a hotkey to start speaking; words appear at the cursor as you talk.

## Features

- **Streaming output** — text appears progressively as speech is recognized, not after you stop talking
- **Types at cursor** — works in any app: editors, browsers, terminals, chat
- **Menu bar icon** — shows idle / recording / transcribing state without a Dock presence
- **Powered by faster-whisper** — accurate, offline transcription using the OpenAI Whisper `small` model
- **VAD-gated** — voice activity detection prevents transcribing silence or background noise

## Requirements

- macOS 12+
- Python 3.10+
- ~500 MB disk space for the Whisper model (downloaded on first run)

## Installation

```bash
git clone https://github.com/jsglazer/vtt.git
cd vtt
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

## Usage

```bash
source .venv/bin/activate
python3 vtt.py
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

macOS will prompt for two permissions on first launch:

1. **Microphone** — required for audio capture
2. **Accessibility** — required for the global hotkey and typing at the cursor

Both can be granted via **System Settings → Privacy & Security**. The app must be restarted after granting Accessibility access.

The Whisper `small` model (~500 MB) is downloaded automatically to `~/.cache/huggingface/hub/` the first time a transcription runs.

## Architecture

```
⌘⇧Space
  └── hotkey.py       GlobalHotKeys toggle
        └── audio.py  sounddevice 16 kHz mono stream (30ms frames)
              └── vad.py     webrtcvad ring-buffer speech detection
                    └── transcriber.py  faster-whisper small/int8/en
                          └── typer.py  pynput keyboard injection at cursor
```

- **`vtt.py`** — entry point; wires components and runs the rumps main loop
- **`audio.py`** — captures 16 kHz mono audio in 480-sample (30ms) frames via `sounddevice`
- **`vad.py`** — ring-buffer VAD state machine: 75% voiced frames to open, 75% silent frames to close a speech segment
- **`transcriber.py`** — worker thread; runs `faster-whisper` with `int8` quantization, language locked to English
- **`typer.py`** — injects text via `pynput`; prepends a space unless the segment starts with punctuation
- **`hotkey.py`** — global hotkey listener via `pynput.GlobalHotKeys`
- **`menubar.py`** — `rumps` menu bar app; all icon updates dispatched to the main thread via `@rumps.timer`

## Configuration

Defaults are set as constants at the top of each module:

| File | Constant | Default | Description |
|---|---|---|---|
| `hotkey.py` | `HOTKEY` | `<cmd>+<shift>+space` | Activation hotkey |
| `transcriber.py` | `MODEL_SIZE` | `small` | Whisper model size (`tiny`, `base`, `small`, `medium`, `large-v2`) |
| `vad.py` | `VOICED_RATIO` | `0.75` | Fraction of voiced frames to start a segment |
| `vad.py` | `SILENCE_RATIO` | `0.75` | Fraction of silent frames to end a segment |
| `vad.py` | `RING_BUFFER_SIZE` | `20` | VAD window size in frames (20 × 30ms = 600ms) |

## Troubleshooting

**Hotkey does nothing**
Grant Accessibility permission in **System Settings → Privacy & Security → Accessibility**, then restart the app.

**No transcription / nothing typed**
Grant Microphone permission in **System Settings → Privacy & Security → Microphone**, then restart.

**Text appears with wrong spacing**
The typer prepends a space before each segment unless it starts with punctuation. If you need no leading space at the start of a document or field, position your cursor after at least one character first.

**Slow first transcription**
The model downloads ~500 MB on first use. Subsequent runs use the local cache.

**webrtcvad import error on Python 3.13**
The installed `webrtcvad` uses `pkg_resources` which is unavailable in Python 3.13 venvs. Patch it:
```bash
sed -i '' 's/import pkg_resources/import importlib.metadata/' \
  .venv/lib/python3.13/site-packages/webrtcvad.py
sed -i '' "s/pkg_resources.get_distribution('webrtcvad').version/importlib.metadata.version('webrtcvad')/" \
  .venv/lib/python3.13/site-packages/webrtcvad.py
```

## License

MIT
