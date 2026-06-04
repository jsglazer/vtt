import AppKit
import ApplicationServices

enum Typer {
    // Characters that immediately follow the previous word — no leading space needed
    private static var noLeadingSpace: CharacterSet = {
        var cs = CharacterSet(charactersIn: ".,!?;:)]}\"'")
        cs.formUnion(.newlines)
        return cs
    }()

    // Tracks whether the last insertion ended with a newline (main-thread only)
    private static var lastEndedWithNewline = true  // true → no spurious space on first use

    static func type(_ text: String) {
        // All flag reads/writes and insertion happen on the main thread
        DispatchQueue.main.async {
            let firstIsControl = text.unicodeScalars.first.map { noLeadingSpace.contains($0) } ?? true
            var output = text
            if !firstIsControl && !lastEndedWithNewline && !cursorAtLineStart() {
                output = " " + text
            }
            lastEndedWithNewline = text.unicodeScalars.last.map { CharacterSet.newlines.contains($0) } ?? false
            guard !output.isEmpty else { return }

            let frontApp = NSWorkspace.shared.frontmostApplication
            let frontName = frontApp?.localizedName ?? "unknown"
            let frontPid  = frontApp?.processIdentifier ?? 0
            print("VTT: inserting into \(frontName): \"\(output)\"")

            if !insertViaAX(output) {
                pasteViaClipboard(output, targetPid: frontPid)
            }
        }
    }

    // Returns true if the character immediately before the cursor is a newline,
    // or if the cursor is at position 0. Handles the case where the user pressed
    // Enter manually — the app wouldn't know otherwise.
    private static func cursorAtLineStart() -> Bool {
        let sys = AXUIElementCreateSystemWide()
        var focused: AnyObject?
        guard AXUIElementCopyAttributeValue(sys, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else { return false }

        var rangeVal: AnyObject?
        guard AXUIElementCopyAttributeValue(element as! AXUIElement,
                                            kAXSelectedTextRangeAttribute as CFString,
                                            &rangeVal) == .success,
              let rangeVal else { return false }

        var cfRange = CFRange()
        guard AXValueGetValue(rangeVal as! AXValue, .cfRange, &cfRange) else { return false }
        guard cfRange.location > 0 else { return true }  // cursor at very start of field

        var prevRange = CFRange(location: cfRange.location - 1, length: 1)
        guard let axPrev = AXValueCreate(.cfRange, &prevRange) else { return false }
        var charVal: AnyObject?
        guard AXUIElementCopyParameterizedAttributeValue(element as! AXUIElement,
                                                         kAXStringForRangeParameterizedAttribute as CFString,
                                                         axPrev,
                                                         &charVal) == .success,
              let ch = charVal as? String else { return false }

        return ch == "\n" || ch == "\r"
    }

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
        print("VTT: AX insert failed (error \(result.rawValue)), falling back to clipboard")
        return false
    }

    // Fallback for apps that don't implement writable AX text attributes
    // (e.g. Sublime Text, VS Code, Vim GUIs — any app with a custom text engine).
    // Saves and restores the clipboard so nothing is lost.
    // Activates the target app so the session event tap delivers ⌘V to the right window
    // even if something briefly grabbed focus during transcription.
    private static func pasteViaClipboard(_ text: String, targetPid: pid_t) {
        let pb = NSPasteboard.general
        let saved = pb.string(forType: .string)
        pb.clearContents()
        pb.setString(text, forType: .string)

        // Bring target to front so the session event tap reaches it
        NSRunningApplication(processIdentifier: targetPid)?.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let src = CGEventSource(stateID: .combinedSessionState)
            if let dn = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true),
               let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false) {
                dn.flags = .maskCommand
                up.flags = .maskCommand
                dn.post(tap: .cgAnnotatedSessionEventTap)
                up.post(tap: .cgAnnotatedSessionEventTap)
            }
            print("VTT: clipboard paste fired to pid \(targetPid)")
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            pb.clearContents()
            if let saved { pb.setString(saved, forType: .string) }
        }
    }
}
