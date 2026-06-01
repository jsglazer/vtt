import Cocoa

final class StatusBarController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private weak var statusLabel: NSMenuItem?

    init() {
        let menu = NSMenu()

        let label = NSMenuItem(title: "Status: Idle", action: nil, keyEquivalent: "")
        label.isEnabled = false
        statusLabel = label
        menu.addItem(label)

        menu.addItem(.separator())
        let hint = NSMenuItem(title: "Hotkey: ⌘⇧Space", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit VTT",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        item.menu = menu
        item.button?.title = "🎤"
    }

    func setIdle() {
        dispatchPrecondition(condition: .onQueue(.main))
        item.button?.title = "🎤"
        statusLabel?.title = "Status: Idle"
    }

    func setRecording() {
        dispatchPrecondition(condition: .onQueue(.main))
        item.button?.title = "🟢🎤"
        statusLabel?.title = "Status: Recording..."
    }

    func setTranscribing() {
        dispatchPrecondition(condition: .onQueue(.main))
        item.button?.title = "💬"
        statusLabel?.title = "Status: Transcribing..."
    }
}
