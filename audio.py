import queue
import numpy as np
import sounddevice as sd

SAMPLE_RATE = 16000
FRAME_MS = 30
FRAME_SAMPLES = int(SAMPLE_RATE * FRAME_MS / 1000)  # 480 samples = 30ms


class AudioCapture:
    def __init__(self):
        self.queue = queue.Queue()
        self._stream = None
        self._active = False

    def _callback(self, indata, frames, time, status):
        if self._active:
            self.queue.put(indata[:, 0].copy())

    def start(self):
        self._active = True
        self._stream = sd.InputStream(
            samplerate=SAMPLE_RATE,
            channels=1,
            dtype='float32',
            blocksize=FRAME_SAMPLES,
            callback=self._callback,
        )
        self._stream.start()

    def stop(self):
        self._active = False
        if self._stream:
            self._stream.stop()
            self._stream.close()
            self._stream = None
