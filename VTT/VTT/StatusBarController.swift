import Cocoa
import os.log

private let log = Logger(subsystem: "com.jsglazer.VTT", category: "statusbar")

final class StatusBarController: NSObject {
    var onToggle: (() -> Void)?
    var onSettings: (() -> Void)?

    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private weak var statusLabel: NSMenuItem?
    private weak var toggleItem: NSMenuItem?

    private enum AppState { case idle, recording, transcribing }
    private var appState: AppState = .idle

    // MARK: Waveform state
    private var barLevels: [Float] = [0, 0, 0]
    private var smoothedRMS: Float = 0
    private var waveformTimer: Timer?
    private let barAlphas: [Float] = [0.50, 0.35, 0.45]

    private static let waveformBarW: CGFloat    = 3
    private static let waveformBarGap: CGFloat  = 2
    private static let waveformBarCount: Int    = 3
    private static let waveformBarMinH: CGFloat = 2
    private static let waveformBarMaxH: CGFloat = 15
    private static let waveformScale: Float     = 6.0
    private static let waveformBaseRMS: Float   = 0.030

    private static let waveAreaW: CGFloat = {
        CGFloat(waveformBarCount) * waveformBarW + CGFloat(waveformBarCount - 1) * waveformBarGap
    }()
    private static let totalIconW: CGFloat = waveAreaW + 3 + 20 // bars + gap + symbol

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
        rebuildIcon()
        log.info("status bar item initialised")
        print("VTT: status bar item initialised")
    }

    // MARK: - Audio level (called on main thread by AudioCapture)

    func updateLevel(_ rms: Float) {
        smoothedRMS = rms
    }

    // MARK: - State

    func setIdle() {
        dispatchPrecondition(condition: .onQueue(.main))
        appState = .idle
        stopWaveformTimer()
        barLevels = [0, 0, 0]
        smoothedRMS = 0
        statusLabel?.title  = "Status: Idle"
        toggleItem?.title   = "Start Recording"
        toggleItem?.isEnabled = true
        rebuildIcon()
    }

    func setRecording() {
        dispatchPrecondition(condition: .onQueue(.main))
        appState = .recording
        startWaveformTimer()
        statusLabel?.title  = "Status: Recording..."
        toggleItem?.title   = "Stop Recording"
        toggleItem?.isEnabled = true
        rebuildIcon()
    }

    func setTranscribing() {
        dispatchPrecondition(condition: .onQueue(.main))
        appState = .transcribing
        stopWaveformTimer()
        statusLabel?.title  = "Status: Transcribing..."
        toggleItem?.title   = "Stop Recording"
        toggleItem?.isEnabled = false
        rebuildIcon()
    }

    // MARK: - Waveform timer

    private func startWaveformTimer() {
        guard waveformTimer == nil else { return }
        waveformTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in
            self?.tickWaveform()
        }
    }

    private func stopWaveformTimer() {
        waveformTimer?.invalidate()
        waveformTimer = nil
    }

    private func tickWaveform() {
        let t = Float(Date().timeIntervalSince1970)
        for i in 0..<barLevels.count {
            let phase = t * 5.0 + Float(i) * 1.8
            let osc = Self.waveformBaseRMS * (0.5 + 0.5 * sin(phase))
            let target = max(smoothedRMS, osc)
            barLevels[i] += barAlphas[i] * (target - barLevels[i])
        }
        rebuildIcon()
    }

    // MARK: - Icon rendering

    private func rebuildIcon() {
        guard let button = item.button else { return }

        let showWaveform: Bool = {
            guard let v = UserDefaults.standard.object(forKey: "vtt.showWaveform") as? Bool else { return true }
            return v
        }()

        let (symbolName, tint): (String, NSColor?) = {
            switch appState {
            case .idle:         return (Icon.idle, nil)
            case .recording:    return (Icon.recording, .systemGreen)
            case .transcribing: return (Icon.transcribing, nil)
            }
        }()

        if showWaveform && appState == .recording {
            let img = makeWaveformIcon(bars: barLevels, symbolName: symbolName, tint: tint)
            item.length = Self.totalIconW
            button.image = img
            button.imageScaling = .scaleNone
        } else {
            item.length = NSStatusItem.squareLength
            var config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            if let tint {
                config = config.applying(.init(paletteColors: [tint]))
            }
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: symbolName)?
                .withSymbolConfiguration(config)
            button.imageScaling = .scaleProportionallyDown
        }
    }

    private func makeWaveformIcon(bars: [Float], symbolName: String, tint: NSColor?) -> NSImage {
        let iconH: CGFloat = 22
        let symW: CGFloat  = 20
        let symH: CGFloat  = 16
        let gapToSym: CGFloat = 3

        var symConfig = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        if let tint { symConfig = symConfig.applying(.init(paletteColors: [tint])) }
        let symImg = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(symConfig)

        let barColor = tint ?? NSColor.labelColor

        return NSImage(size: NSSize(width: Self.totalIconW, height: iconH), flipped: false) { _ in
            barColor.setFill()
            for (i, level) in bars.enumerated() {
                let fraction = CGFloat(min(1, max(0, level) * Self.waveformScale))
                let h = Self.waveformBarMinH + (Self.waveformBarMaxH - Self.waveformBarMinH) * fraction
                let x = CGFloat(i) * (Self.waveformBarW + Self.waveformBarGap)
                let y = (iconH - h) / 2
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: Self.waveformBarW, height: h),
                             xRadius: 1, yRadius: 1).fill()
            }
            symImg?.draw(in: NSRect(x: Self.waveAreaW + gapToSym,
                                    y: (iconH - symH) / 2,
                                    width: symW, height: symH))
            return true
        }
    }

    // MARK: - Actions

    @objc private func handleToggle() { onToggle?() }
    @objc private func handleSettings() { onSettings?() }
}
