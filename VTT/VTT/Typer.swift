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

            let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
            print("VTT: inserting into \(frontApp): \"\(output)\"")

            if !insertViaAX(output) {
                print("VTT: text dropped — AX insertion unavailable in this app")
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
        print("VTT: AX insert failed (error \(result.rawValue))")
        return false
    }
}
