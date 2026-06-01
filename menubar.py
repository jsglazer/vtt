import rumps

ICON_IDLE = '🎤'
ICON_RECORDING = '🟢🎤'
ICON_TRANSCRIBING = '💬'


class MenuBarApp(rumps.App):
    def __init__(self, on_quit):
        super().__init__(ICON_IDLE, quit_button=None)
        self._on_quit_cb = on_quit
        self._target_icon = ICON_IDLE
        self._target_status = 'Status: Idle'
        self._status = rumps.MenuItem('Status: Idle')
        self.menu = [
            self._status,
            None,
            rumps.MenuItem('Hotkey: ⌘⇧Space', callback=None),
            None,
            rumps.MenuItem('Quit', callback=self._quit),
        ]

    @rumps.timer(0.1)
    def _sync(self, _):
        # All UI updates happen on the main thread via this timer
        self.title = self._target_icon
        self._status.title = self._target_status

    def set_idle(self):
        self._target_icon = ICON_IDLE
        self._target_status = 'Status: Idle'

    def set_recording(self):
        self._target_icon = ICON_RECORDING
        self._target_status = 'Status: Recording...'

    def set_transcribing(self):
        self._target_icon = ICON_TRANSCRIBING
        self._target_status = 'Status: Transcribing...'

    def _quit(self, _):
        self._on_quit_cb()
        rumps.quit_application()
