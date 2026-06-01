import Foundation

final class VAD {
    // RMS level that counts as speech
    var speechThreshold: Float = 0.01
    // Minimum samples before a segment can close (~1 s at 16 kHz)
    var minSpeechSamples: Int = 16_000
    // Silence samples needed to close an utterance (~0.6 s at 16 kHz)
    var silenceSamples: Int = 9_600

    var onUtterance: (([Float]) -> Void)?

    private enum State { case silent, speaking }
    private var state: State = .silent
    private var buffer: [Float] = []
    private var silenceCount = 0

    /// Feed a chunk of 16 kHz mono audio. Calls `onUtterance` when speech ends.
    func process(_ samples: [Float]) {
        let voiced = rms(samples) >= speechThreshold

        switch state {
        case .silent:
            if voiced {
                state = .speaking
                buffer = samples
                silenceCount = 0
            }
        case .speaking:
            buffer.append(contentsOf: samples)
            if voiced {
                silenceCount = 0
            } else {
                silenceCount += samples.count
                if silenceCount >= silenceSamples && buffer.count >= minSpeechSamples {
                    emit()
                }
            }
        }
    }

    /// Emit any buffered speech immediately (called on recording stop).
    /// Returns true if audio was emitted.
    @discardableResult
    func flush() -> Bool {
        guard state == .speaking, buffer.count >= minSpeechSamples else {
            reset()
            return false
        }
        emit()
        return true
    }

    private func emit() {
        onUtterance?(buffer)
        reset()
    }

    private func reset() {
        buffer = []
        silenceCount = 0
        state = .silent
    }

    private func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
    }
}
