import AppKit
import CoreGraphics

enum Typer {
    private static let punctuationStart = CharacterSet(charactersIn: ".,!?;:)]}\"'")

    static func type(_ text: String) {
        var output = text
        if let first = text.unicodeScalars.first, !punctuationStart.contains(first) {
            output = " " + text
        }
        guard !output.isEmpty else { return }

        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(output, forType: .string)

        // Simulate ⌘V to paste into whatever app has focus
        let source = CGEventSource(stateID: .hidSystemState)
        if let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
           let up   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
            down.flags = .maskCommand
            up.flags   = .maskCommand
            down.post(tap: .cgSessionEventTap)
            up.post(tap: .cgSessionEventTap)
        }

        // Restore clipboard after paste lands
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            pasteboard.clearContents()
            if let saved { pasteboard.setString(saved, forType: .string) }
        }

        print("VTT: typed → \"\(output)\"")
    }
}
