import Foundation
import WhisperKit

final class Transcriber {
    private var kit: WhisperKit?
    private(set) var isReady = false
    var onSegment: ((String) -> Void)?
    var onTranscriptionDone: (() -> Void)?

    private static let modelName = "openai_whisper-large-v3-turbo"

    func load() async {
        do {
            // WhisperKit downloads to ~/Documents/huggingface/models/openai/<model>/
            // but doesn't pre-create the model folder; the move step fails if it's absent.
            let modelDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents/huggingface/models/openai/\(Self.modelName)")
            try? FileManager.default.createDirectory(at: modelDir, withIntermediateDirectories: true)

            kit = try await WhisperKit(model: Self.modelName, verbose: false)
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

    // Strips both (parenthetical) and [bracket] Whisper annotation forms
    private static let annotationRegex = try? NSRegularExpression(pattern: "\\([^)]*\\)|\\[[^\\]]*\\]")

    // Strips commas anywhere and terminal .?!;: (Whisper adds these automatically)
    private static let autoPunctuationRegex = try? NSRegularExpression(pattern: ",|[.?!;:](?=\\s|$)")

    private static func clean(_ raw: String) -> String {
        var text = raw
        for token in noiseTokens {
            text = text.replacingOccurrences(of: token, with: "")
        }
        if let re = annotationRegex {
            let range = NSRange(text.startIndex..., in: text)
            text = re.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        }
        if let re = autoPunctuationRegex {
            let range = NSRange(text.startIndex..., in: text)
            text = re.stringByReplacingMatches(in: text, range: range, withTemplate: "")
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
