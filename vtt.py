"""VTT v1.0.0 — voice-to-text at cursor via faster-whisper + webrtcvad"""
import threading
from audio import AudioCapture
from vad import VoiceActivityDetector
from transcriber import Transcriber
from typer import Typer
from hotkey import HotkeyListener
from menubar import MenuBarApp


class VTT:
    def __init__(self):
        self._recording = False
        self._lock = threading.Lock()

        self._typer = Typer()
        self._audio = AudioCapture()
        self._transcriber = Transcriber(on_segment=self._on_segment)
        self._vad = VoiceActivityDetector(
            audio_queue=self._audio.queue,
            on_speech=self._transcriber.transcribe,
        )
        self._hotkey = HotkeyListener(on_toggle=self._toggle)
        self._app = MenuBarApp(on_quit=self._shutdown)

    def _on_segment(self, text):
        self._typer.type_text(text)
        if not self._recording:
            self._app.set_idle()

    def _toggle(self):
        with self._lock:
            if self._recording:
                self._stop()
            else:
                self._start()

    def _start(self):
        self._recording = True
        self._app.set_recording()
        self._vad.start()
        self._audio.start()

    def _stop(self):
        self._recording = False
        self._app.set_transcribing()
        self._audio.stop()
        self._vad.stop()  # flushes remaining speech buffer before returning

    def _shutdown(self):
        if self._recording:
            self._stop()
        self._transcriber.stop()
        self._hotkey.stop()

    def run(self):
        self._transcriber.start()
        self._hotkey.start()
        self._app.run()  # blocks on main thread (required by macOS)


if __name__ == '__main__':
    VTT().run()
