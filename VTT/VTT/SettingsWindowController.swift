import AppKit
import SwiftUI

final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let vc = NSHostingController(rootView: SettingsView())
            let w = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: true
            )
            w.title = "VTT Settings"
            w.contentViewController = vc
            w.isReleasedWhenClosed = false
            (w as? NSPanel)?.hidesOnDeactivate = false
            window = w
        }
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
