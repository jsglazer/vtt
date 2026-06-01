import Foundation

final class VAD {
    var speechThreshold: Float = 0.02
    // Minimum samples before a segment can close (~0.5 s at 16 kHz)
    var minSpeechSamples: Int = 8_000
    // Silence samples needed to close an utterance (~0.4 s at 16 kHz)
    var silenceSamples: Int = 6_400
    // Pre-roll: audio captured before RMS crosses the threshold (~0.5 s at 16 kHz).
    // Prevents the first syllable of each utterance from being clipped.
    private let prerollCapacity = 8_000

    var onUtterance: (([Float]) -> Void)?

    private enum State { case silent, speaking }
    private var state: State = .silent
    private var buffer: [Float] = []
    private var preroll: [Float] = []
    private var silenceCount = 0

    func process(_ samples: [Float]) {
        let voiced = rms(samples) >= speechThreshold

        switch state {
        case .silent:
            // Maintain a rolling window of recent audio so the onset of speech isn't lost
            preroll.append(contentsOf: samples)
            if preroll.count > prerollCapacity {
                preroll.removeFirst(preroll.count - prerollCapacity)
            }
            if voiced {
                state = .speaking
                buffer = preroll + samples
                preroll = []
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
        preroll = []
        silenceCount = 0
        state = .silent
    }

    private func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
    }
}
