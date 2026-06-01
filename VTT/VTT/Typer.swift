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

        // NSPasteboard and CGEvent posting must run on the main thread
        DispatchQueue.main.async {
            let pasteboard = NSPasteboard.general
            let saved = pasteboard.string(forType: .string)

            pasteboard.clearContents()
            pasteboard.setString(output, forType: .string)

            // Brief delay to let the pasteboard commit before sending ⌘V
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let source = CGEventSource(stateID: .combinedSessionState)
                if let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
                   let up   = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) {
                    down.flags = .maskCommand
                    up.flags   = .maskCommand
                    down.post(tap: .cgSessionEventTap)
                    up.post(tap: .cgSessionEventTap)
                }
                print("VTT: pasted → \"\(output)\"")
            }

            // Restore clipboard after paste lands
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                pasteboard.clearContents()
                if let saved { pasteboard.setString(saved, forType: .string) }
            }
        }
    }
}
