import Foundation
import WhisperKit

final class Transcriber {
    private var kit: WhisperKit?
    private(set) var isReady = false
    var onSegment: ((String) -> Void)?
    var onTranscriptionDone: (() -> Void)?

    private static let modelName = "openai_whisper-large-v2"

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

    // Spoken punctuation: ordered longest-phrase-first to avoid partial matches
    private static let spokenPunctuation: [(regex: NSRegularExpression, replacement: String)] = {
        let pairs: [(String, String)] = [
            ("question mark",     "?"),
            ("exclamation mark",  "!"),
            ("exclamation point", "!"),
            ("open parenthesis",  "("),
            ("close parenthesis", ")"),
            ("open paren",        "("),
            ("close paren",       ")"),
            ("full stop",         "."),
            ("dot dot dot",       "…"),
            ("ellipsis",          "…"),
            ("semicolon",         ";"),
            ("colon",             ":"),
            ("hyphen",            "-"),
            ("period",            "."),
            ("comma",             ","),
            ("dash",              " — "),
        ]
        return pairs.compactMap { word, replacement in
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: word))\\b"
            guard let re = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
            return (re, replacement)
        }
    }()

    // Removes the space that spoken-punct replacement leaves before attached symbols
    private static let spaceBeforePunctRegex = try? NSRegularExpression(pattern: "\\s+([.?!,;:])")

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
        for (re, replacement) in spokenPunctuation {
            let range = NSRange(text.startIndex..., in: text)
            text = re.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
        }
        if let re = spaceBeforePunctRegex {
            let range = NSRange(text.startIndex..., in: text)
            text = re.stringByReplacingMatches(in: text, range: range, withTemplate: "$1")
        }
        text = collapseRepetitions(text.trimmingCharacters(in: .whitespacesAndNewlines))
        return text
    }

    // Collapses exact whole-string repetitions produced by Whisper hallucination
    // (e.g. "word word word word" → "word word").
    private static func collapseRepetitions(_ text: String) -> String {
        let words = text.split(separator: " ").map(String.init)
        guard words.count >= 4 else { return text }
        let mid = words.count / 2
        guard words.count == mid * 2 else { return text }
        if Array(words[0..<mid]) == Array(words[mid...]) {
            return words[0..<mid].joined(separator: " ")
        }
        return text
    }

    func transcribe(_ samples: [Float]) {
        guard isReady, let kit else { return }
        Task.detached(priority: .userInitiated) { [weak self] in
            defer { self?.onTranscriptionDone?() }
            do {
                let options = DecodingOptions(
                    task: .transcribe,
                    language: "en",
                    sampleLength: 128,       // cap at ~100 words per segment; skips excess decoder steps
                    withoutTimestamps: true  // skip timestamp alignment — not needed for typing
                )
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
