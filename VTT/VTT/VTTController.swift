import Foundation

final class VTTController {
    private let statusBar  = StatusBarController()
    private let hotkey     = HotkeyManager()
    private let audio      = AudioCapture()
    private let vad        = VAD()
    private let transcriber = Transcriber()
    private let settingsWC = SettingsWindowController()
    private var isRecording = false
    private var autoNewLineTimer: Timer?
    private var lastSegmentText = ""

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
        await MainActor.run {
            statusBar.setModelName(Transcriber.displayName)
        }
    }

    private func wire() {
        // Audio level → waveform (dispatched to main by AudioCapture)
        audio.onLevel = { [weak self] rms in
            self?.statusBar.updateLevel(rms)
        }

        // Audio → VAD (called on AVAudioEngine thread)
        audio.onSamples = { [weak self] samples in
            self?.vad.process(samples)
        }

        // VAD → Transcriber (called on AVAudioEngine thread)
        vad.onUtterance = { [weak self] samples in
            DispatchQueue.main.async {
                self?.cancelAutoNewLineTimer()
                self?.lastSegmentText = ""
                // Only show transcribing icon after recording stops; during active recording
                // keep the waveform icon to avoid it flashing on every segment
                if self?.isRecording == false {
                    self?.statusBar.setTranscribing()
                }
            }
            self?.transcriber.transcribe(samples)
        }

        // Transcriber → Typer (called on background Task)
        transcriber.onSegment = { [weak self] text in
            DispatchQueue.main.async { self?.lastSegmentText = text }
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
                if self.isRecording {
                    self.statusBar.setRecording()
                } else {
                    self.statusBar.setIdle()
                }
                // Schedule auto-newline regardless of recording state so it fires
                // after the final phrase when the user stops recording
                self.scheduleAutoNewLineTimer()
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
        cancelAutoNewLineTimer()
        audio.stop()
        let flushed = vad.flush()
        if !flushed { statusBar.setIdle() }
        // If flushed, the transcriber callback will call setIdle() after typing
    }

    private func scheduleAutoNewLineTimer() {
        cancelAutoNewLineTimer()
        guard UserDefaults.standard.bool(forKey: "vtt.autoNewLine") else { return }
        guard lastSegmentText.count > 10 else { return }   // ignore noise / blank transcriptions
        let delay = UserDefaults.standard.double(forKey: "vtt.autoNewLineDelay")
        let d = delay > 0 ? delay : 2.0
        autoNewLineTimer = Timer.scheduledTimer(withTimeInterval: d, repeats: false) { [weak self] _ in
            guard let self else { return }
            let sentenceEnders = CharacterSet(charactersIn: ".?!…")
            let needsPeriod = self.lastSegmentText.unicodeScalars.last
                .map { !sentenceEnders.contains($0) } ?? false
            Typer.type(needsPeriod ? ".\n\n" : "\n\n")
            self.lastSegmentText = ""
            self.autoNewLineTimer = nil
        }
    }

    private func cancelAutoNewLineTimer() {
        autoNewLineTimer?.invalidate()
        autoNewLineTimer = nil
    }

    func shutdown() {
        if isRecording { stopRecording() }
    }
}
