from pynput.keyboard import Controller

PUNCTUATION_START = set('.,!?;:)]}')


class Typer:
    def __init__(self):
        self._kb = Controller()

    def type_text(self, text):
        if text and text[0] not in PUNCTUATION_START:
            text = ' ' + text
        self._kb.type(text)
