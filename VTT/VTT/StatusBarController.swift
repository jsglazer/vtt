import Cocoa
import os.log

private let log = Logger(subsystem: "com.jsglazer.VTT", category: "statusbar")

final class StatusBarController: NSObject {
    var onToggle: (() -> Void)?
    var onSettings: (() -> Void)?

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var statusLabel: NSMenuItem?
    private weak var toggleItem: NSMenuItem?

    private enum Icon {
        static let idle         = "microphone.and.signal.meter"
        static let recording    = "microphone.and.signal.meter.fill"
        static let transcribing = "ellipsis.bubble"
    }

    override init() {
        super.init()

        let menu = NSMenu()

        let toggle = NSMenuItem(title: "Start Recording", action: #selector(handleToggle), keyEquivalent: "r")
        toggle.target = self
        self.toggleItem = toggle
        menu.addItem(toggle)

        menu.addItem(.separator())

        let label = NSMenuItem(title: "Status: Idle", action: nil, keyEquivalent: "")
        label.isEnabled = false
        self.statusLabel = label
        menu.addItem(label)

        menu.addItem(.separator())

        let hint = NSMenuItem(title: "Hotkey: ⌘⇧Space", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(handleSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        menu.addItem(NSMenuItem(
            title: "Quit VTT",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        item.menu = menu
        item.isVisible = true
        setImage(Icon.idle, tint: nil)
        log.info("status bar item initialised")
        print("VTT: status bar item initialised")
    }

    // MARK: - State

    func setIdle() {
        dispatchPrecondition(condition: .onQueue(.main))
        setImage(Icon.idle, tint: nil)
        statusLabel?.title  = "Status: Idle"
        toggleItem?.title   = "Start Recording"
        toggleItem?.isEnabled = true
    }

    func setRecording() {
        dispatchPrecondition(condition: .onQueue(.main))
        setImage(Icon.recording, tint: .systemGreen)
        statusLabel?.title  = "Status: Recording..."
        toggleItem?.title   = "Stop Recording"
        toggleItem?.isEnabled = true
    }

    func setTranscribing() {
        dispatchPrecondition(condition: .onQueue(.main))
        setImage(Icon.transcribing, tint: nil)
        statusLabel?.title  = "Status: Transcribing..."
        toggleItem?.title   = "Stop Recording"
        toggleItem?.isEnabled = false
    }

    // MARK: - Private

    @objc private func handleToggle() { onToggle?() }
    @objc private func handleSettings() { onSettings?() }

    private func setImage(_ symbolName: String, tint: NSColor?) {
        guard let button = item.button else {
            log.error("NSStatusItem button is nil")
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
