import Foundation

final class VTTController {
    private let statusBar = StatusBarController()
    private let hotkey   = HotkeyManager()
    private let audio    = AudioCapture()
    private let vad      = VAD()
    private let transcriber = Transcriber()
    private var isRecording = false

    init() { wire() }

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

        // Hotkey → toggle (dispatched to main by HotkeyManager)
        hotkey.onToggle = { [weak self] in self?.toggle() }
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
