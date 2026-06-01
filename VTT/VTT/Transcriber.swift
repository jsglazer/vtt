import Foundation
import WhisperKit

final class Transcriber {
    private var kit: WhisperKit?
    private(set) var isReady = false
    var onSegment: ((String) -> Void)?
    var onTranscriptionDone: (() -> Void)?

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

    // Whisper outputs these when it sees silence or noise instead of speech
    private static let noiseTokens: Set<String> = [
        "[BLANK_AUDIO]", "[blank_audio]",
        "[NOISE]", "[noise]",
        "[silence]", "(silence)",
        "[Music]", "[music]",
        "[Applause]", "[applause]",
    ]

    private static let soundEffectRegex = try? NSRegularExpression(pattern: "\\([^)]*\\)")

    private static func clean(_ raw: String) -> String {
        var text = raw
        for token in noiseTokens {
            text = text.replacingOccurrences(of: token, with: "")
        }
        // Strip Whisper sound-effect annotations: (sniffles), (keyboard clacking), etc.
        if let re = soundEffectRegex {
            let range = NSRange(text.startIndex..., in: text)
            text = re.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Enqueues transcription on a background Task. Calls `onSegment` when text is ready.
    func transcribe(_ samples: [Float]) {
        guard isReady, let kit else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            defer { self?.onTranscriptionDone?() }
            do {
                let options = DecodingOptions(task: .transcribe, language: "en")
                let results = try await kit.transcribe(audioArray: samples, decodeOptions: options)
                let text = results
                    .map { $0.text }
                    .joined(separator: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                print("VTT: transcribed → \"\(text)\"")
                let clean = Self.clean(text)
                guard !clean.isEmpty else { return }
                self?.onSegment?(clean)
            } catch {
                print("VTT: transcription error — \(error)")
            }
        }
    }
}
