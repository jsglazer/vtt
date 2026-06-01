from pynput import keyboard

HOTKEY = '<cmd>+<shift>+space'


class HotkeyListener:
    def __init__(self, on_toggle):
        self._on_toggle = on_toggle
        self._listener = None

    def start(self):
        self._listener = keyboard.GlobalHotKeys({HOTKEY: self._on_toggle})
        self._listener.start()

    def stop(self):
        if self._listener:
            self._listener.stop()
