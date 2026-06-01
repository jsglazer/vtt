import Foundation
import WhisperKit

final class Transcriber {
    private var kit: WhisperKit?
    private(set) var isReady = false
    var onSegment: ((String) -> Void)?
    var onTranscriptionDone: (() -> Void)?

    private static let modelName = "openai_whisper-medium.en"

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

    // Spoken phrase → inserted text. Include common Whisper misrecognitions as aliases.
    // Longer phrases first so a substring doesn't shadow a full match.
    private static let voiceCommands: [(phrase: String, replacement: String)] = [
        ("end of note here", "\n\n"),
        ("and of note here", "\n\n"),
        ("and note here",    "\n\n"),
        ("end note here",    "\n\n"),
    ]

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

    private static func applyCommands(_ text: String) -> String {
        var result = text
        for (phrase, replacement) in voiceCommands {
            result = result.replacingOccurrences(of: phrase, with: replacement, options: .caseInsensitive)
        }
        return result
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
                let processed = Self.applyCommands(Self.clean(text))
                // Use .whitespaces (not .whitespacesAndNewlines) so \n\n from commands survives
                guard !processed.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                self?.onSegment?(processed)
            } catch {
                print("VTT: transcription error — \(error)")
            }
        }
    }
}
