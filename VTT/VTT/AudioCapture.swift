import AVFoundation

final class AudioCapture {
    var onSamples: (([Float]) -> Void)?
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private let processingQueue = DispatchQueue(label: "com.jsglazer.VTT.audio-processing", qos: .userInitiated)
    private var converter: AVAudioConverter?
    private let targetFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!

    // Larger buffer → fewer callbacks/sec → more CPU headroom during Whisper
    private let tapBufferSize: AVAudioFrameCount = 8_192

    func start() throws {
        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard let conv = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioError.converterUnavailable
        }
        converter = conv

        let outputCapacity = AVAudioFrameCount(
            ceil(Double(tapBufferSize) * targetFormat.sampleRate / inputFormat.sampleRate)
        ) + 1

        input.installTap(onBus: 0, bufferSize: tapBufferSize, format: inputFormat) { [weak self] buffer, _ in
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
        let rms = Self.rms(samples)
        DispatchQueue.main.async { [weak self] in self?.onLevel?(rms) }
        processingQueue.async { [weak self] in self?.onSamples?(samples) }
    }

    private static func rms(_ samples: [Float]) -> Float {
        guard !samples.isEmpty else { return 0 }
        return sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
    }
}

enum AudioError: Error {
    case converterUnavailable
}
