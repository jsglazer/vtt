import AVFoundation

final class AudioCapture {
    var onSamples: (([Float]) -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    func start() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.converterUnavailable
        }
        converter = conv

        let outputCapacity = AVAudioFrameCount(
            ceil(4096.0 * targetFormat.sampleRate / inputFormat.sampleRate)
        ) + 1

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.convert(buffer, capacity: outputCapacity)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
    }

    private func convert(_ buffer: AVAudioPCMBuffer, capacity: AVAudioFrameCount) {
        guard let converter,
              let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity)
        else { return }

        var error: NSError?
        let status = converter.convert(to: out, error: &error) { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard (status == .haveData || status == .endOfStream),
              let data = out.floatChannelData?[0],
              out.frameLength > 0
        else { return }

        let samples = Array(UnsafeBufferPointer(start: data, count: Int(out.frameLength)))
        onSamples?(samples)
    }
}

enum AudioError: Error {
    case converterUnavailable
}
