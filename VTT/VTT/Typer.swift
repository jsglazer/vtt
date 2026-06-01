import AppKit
import ApplicationServices

enum Typer {
    // Characters that should follow the previous word directly, without a leading space
    private static var noLeadingSpace: CharacterSet = {
        var cs = CharacterSet(charactersIn: ".,!?;:)]}\"'")
        cs.formUnion(.newlines)
        return cs
    }()

    static func type(_ text: String) {
        var output = text
        if let first = text.unicodeScalars.first, !noLeadingSpace.contains(first) {
            output = " " + text
        }
        guard !output.isEmpty else { return }

        DispatchQueue.main.async {
            let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
            print("VTT: inserting into \(frontApp): \"\(output)\"")

            if insertViaAX(output) { return }
            pasteViaClipboard(output)
        }
    }

    // Inserts text directly at the focused UI element via Accessibility API.
    // Works in any app that supports AX (TextEdit, Safari, Notes, VS Code, etc.).
    private static func insertViaAX(_ text: String) -> Bool {
        let sys = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else {
            print("VTT: AX — no focused element")
            return false
        }
        let result = AXUIElementSetAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        if result == .success {
            print("VTT: AX insert OK")
            return true
        }
        print("VTT: AX insert failed (error \(result.rawValue)), trying clipboard")
        return false
    }

    // Fallback: put text on clipboard and simulate ⌘V.
    private static func pasteViaClipboard(_ text: String) {
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let src = CGEventSource(stateID: .combinedSessionState)
            if let dn = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) {
                dn.flags = .maskCommand
                up.flags = .maskCommand
                dn.post(tap: .cgSessionEventTap)
                up.post(tap: .cgSessionEventTap)
            }
            print("VTT: clipboard paste fired")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pb.clearContents()
            if let saved { pb.setString(saved, forType: .string) }
        }
    }
}
