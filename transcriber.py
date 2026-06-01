import queue
import threading
from faster_whisper import WhisperModel

MODEL_SIZE = 'small'


class Transcriber:
    def __init__(self, on_segment):
        self.on_segment = on_segment
        self._queue = queue.Queue()
        self._thread = None
        self._running = False
        self._model = None

    def _load(self):
        self._model = WhisperModel(MODEL_SIZE, compute_type='int8')

    def _run(self):
        self._load()
        while self._running:
            try:
                audio = self._queue.get(timeout=0.1)
            except queue.Empty:
                continue

            segments, _ = self._model.transcribe(
                audio,
                language='en',
                beam_size=5,
                vad_filter=False,
            )
            for seg in segments:
                text = seg.text.strip()
                if text:
                    self.on_segment(text)

    def transcribe(self, audio):
        self._queue.put(audio)

    def start(self):
        self._running = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False
        if self._thread:
            self._thread.join(timeout=10)
