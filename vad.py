import queue
import threading
import collections
import numpy as np
import webrtcvad

SAMPLE_RATE = 16000
FRAME_SAMPLES = 480  # 30ms at 16kHz

RING_BUFFER_SIZE = 20  # 600ms window
VOICED_RATIO = 0.75   # fraction of voiced frames needed to start speech
SILENCE_RATIO = 0.75  # fraction of silent frames needed to end speech


class VoiceActivityDetector:
    def __init__(self, audio_queue, on_speech):
        self.audio_queue = audio_queue
        self.on_speech = on_speech
        self._vad = webrtcvad.Vad(2)
        self._running = False
        self._thread = None

    def _is_speech(self, frame):
        pcm = (frame * 32767).astype(np.int16).tobytes()
        try:
            return self._vad.is_speech(pcm, SAMPLE_RATE)
        except Exception:
            return False

    def _run(self):
        ring_buffer = collections.deque(maxlen=RING_BUFFER_SIZE)
        voiced_frames = []
        triggered = False

        while self._running:
            try:
                frame = self.audio_queue.get(timeout=0.05)
            except queue.Empty:
                continue

            is_speech = self._is_speech(frame)

            if not triggered:
                ring_buffer.append((frame, is_speech))
                num_voiced = sum(1 for _, s in ring_buffer if s)
                if num_voiced / max(len(ring_buffer), 1) >= VOICED_RATIO:
                    triggered = True
                    voiced_frames = [f for f, _ in ring_buffer]
                    ring_buffer.clear()
            else:
                voiced_frames.append(frame)
                ring_buffer.append((frame, is_speech))
                num_unvoiced = sum(1 for _, s in ring_buffer if not s)
                if num_unvoiced / max(len(ring_buffer), 1) >= SILENCE_RATIO:
                    self._emit(voiced_frames)
                    triggered = False
                    voiced_frames = []
                    ring_buffer.clear()

        # Flush any buffered speech on stop
        if triggered and voiced_frames:
            self._emit(voiced_frames)

    def _emit(self, frames):
        if frames:
            self.on_speech(np.concatenate(frames))

    def start(self):
        self._running = True
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def stop(self):
        self._running = False
        if self._thread:
            self._thread.join(timeout=3)
