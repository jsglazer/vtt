import Cocoa

final class StatusBarController {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var statusLabel: NSMenuItem?

    // SF Symbols used for each state
    private enum Icon {
        static let idle         = "mic"
        static let recording    = "mic.fill"       // filled = active; tint green below
        static let transcribing = "ellipsis.bubble"
    }

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
        item.isVisible = true
        setImage(Icon.idle, tint: nil)
        print("VTT: status bar item initialised")
    }

    func setIdle() {
        dispatchPrecondition(condition: .onQueue(.main))
        setImage(Icon.idle, tint: nil)
        statusLabel?.title = "Status: Idle"
    }

    func setRecording() {
        dispatchPrecondition(condition: .onQueue(.main))
        setImage(Icon.recording, tint: .systemGreen)
        statusLabel?.title = "Status: Recording..."
    }

    func setTranscribing() {
        dispatchPrecondition(condition: .onQueue(.main))
        setImage(Icon.transcribing, tint: nil)
        statusLabel?.title = "Status: Transcribing..."
    }

    private func setImage(_ symbolName: String, tint: NSColor?) {
        guard let button = item.button else {
            print("VTT: NSStatusItem button is nil")
            return
        }
        var config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        if let tint {
            config = config.applying(.init(paletteColors: [tint]))
        }
        button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbolName)?
            .withSymbolConfiguration(config)
        button.imageScaling = .scaleProportionallyDown
    }
}
