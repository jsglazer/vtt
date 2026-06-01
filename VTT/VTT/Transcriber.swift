import Foundation
import WhisperKit

final class Transcriber {
    private var kit: WhisperKit?
    private(set) var isReady = false
    var onSegment: ((String) -> Void)?

    func load() async {
        do {
            // openai_whisper-small.en is the English-only small model — faster than multilingual
            kit = try await WhisperKit(model: "openai_whisper-small.en", verbose: false)
            isReady = true
            print("VTT: model ready")
        } catch {
            print("VTT: model load failed — \(error)")
        }
    }

    /// Enqueues transcription on a background Task. Calls `onSegment` when text is ready.
    func transcribe(_ samples: [Float]) {
        guard isReady, let kit else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            do {
                let options = DecodingOptions(task: .transcribe, language: "en")
                let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
                let text = results
                    .map { $0.text }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                self?.onSegment?(text)
            } catch {
                print("VTT: transcription error — \(error)")
            }
        }
    }
}
