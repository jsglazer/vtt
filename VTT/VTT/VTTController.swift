import Foundation

final class VTTController {
    private let statusBar  = StatusBarController()
    private let hotkey     = HotkeyManager()
    private let audio      = AudioCapture()
    private let vad        = VAD()
    private let transcriber = Transcriber()
    private let settingsWC = SettingsWindowController()
    private var isRecording = false

    init() {
        applyStoredSettings()
        wire()
        // Re-apply whenever the user moves a slider
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in self?.applyStoredSettings() }
    }

    func loadModel() async {
        await transcriber.load()
    }

    private func wire() {
        // Audio → VAD (called on AVAudioEngine thread)
        audio.onSamples = { [weak self] samples in
            self?.vad.process(samples)
        }

        // VAD → Transcriber (called on AVAudioEngine thread)
        vad.onUtterance = { [weak self] samples in
            DispatchQueue.main.async { self?.statusBar.setTranscribing() }
            self?.transcriber.transcribe(samples)
        }

        // Transcriber → Typer (called on background Task)
        transcriber.onSegment = { [weak self] text in
            Typer.type(text)
            DispatchQueue.main.async {
                self?.isRecording == true
                    ? self?.statusBar.setRecording()
                    : self?.statusBar.setIdle()
            }
        }

        // Always return to correct state after transcription finishes (even if text was empty)
        transcriber.onTranscriptionDone = { [weak self] in
            DispatchQueue.main.async {
                guard let self else { return }
                if !self.isRecording { self.statusBar.setIdle() }
            }
        }

        // Hotkey → toggle (dispatched to main by HotkeyManager)
        hotkey.onToggle = { [weak self] in self?.toggle() }

        // Menu bar Start/Stop button → toggle
        statusBar.onToggle = { [weak self] in self?.toggle() }

        // Menu bar Settings → open panel
        statusBar.onSettings = { [weak self] in self?.settingsWC.show() }
    }

    private func applyStoredSettings() {
        let ud = UserDefaults.standard
        if let v = ud.object(forKey: "vtt.speechThreshold")   as? Double { vad.speechThreshold  = Float(v) }
        if let v = ud.object(forKey: "vtt.silenceTimeout")    as? Double { vad.silenceSamples    = Int(v * 16_000) }
        if let v = ud.object(forKey: "vtt.minSpeechDuration") as? Double { vad.minSpeechSamples  = Int(v * 16_000) }
    }

    private func toggle() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        guard transcriber.isReady else {
            print("VTT: model still loading, please wait")
            return
        }
        isRecording = true
        statusBar.setRecording()
        do {
            try audio.start()
        } catch {
            print("VTT: audio error — \(error)")
            isRecording = false
            statusBar.setIdle()
        }
    }

    private func stopRecording() {
        isRecording = false
        audio.stop()
        let flushed = vad.flush()
        if !flushed { statusBar.setIdle() }
        // If flushed, the transcriber callback will call setIdle() after typing
    }

    func shutdown() {
        if isRecording { stopRecording() }
    }
}
