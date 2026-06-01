import Foundation
import CoreGraphics

enum Typer {
    private static let punctuationStart = CharacterSet(charactersIn: ".,!?;:)]}\"'")

    /// Injects `text` at the current cursor position using CGEvent Unicode string injection.
    /// Prepends a space unless the text starts with punctuation.
    static func type(_ text: String) {
        var output = text
        if let first = text.unicodeScalars.first, !punctuationStart.contains(first) {
            output = " " + text
        }

        let source = CGEventSource(stateID: .hidSystemState)
        let utf16 = Array(output.utf16)
        guard !utf16.isEmpty else { return }

        guard
            let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
            let up   = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false)
        else { return }

        down.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        up.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
        down.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }
}
