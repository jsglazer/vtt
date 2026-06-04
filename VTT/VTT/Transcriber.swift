import Foundation
import WhisperKit

final class Transcriber {
    private var kit: WhisperKit?
    private(set) var isReady = false
    var onSegment: ((String) -> Void)?
    var onTranscriptionDone: (() -> Void)?
    /// Called on the main thread with (fractionCompleted 0–1, status label).
    var onProgress: ((Double, String) -> Void)?

    private static let modelName = "openai_whisper-large-v2"
    static let displayName = "Whisper large-v2"

    // WhisperKit caches models under ~/Documents/huggingface/models/argmaxinc/whisperkit-coreml/
    private static var modelCacheURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/huggingface/models/argmaxinc/whisperkit-coreml/\(modelName)")
    }

    private static func isModelCached() -> Bool {
        FileManager.default.fileExists(atPath: modelCacheURL.appendingPathComponent("config.json").path)
    }

    func load() async {
        do {
            let modelFolder: URL
            if Self.isModelCached() {
                notifyProgress(0.0, "Loading model…")
                modelFolder = Self.modelCacheURL
            } else {
                notifyProgress(0.0, "Downloading model…")
                modelFolder = try await WhisperKit.download(
                    variant: Self.modelName,
                    progressCallback: { [weak self] progress in
                        let frac = progress.fractionCompleted
                        let label = frac < 0.01
                            ? "Downloading model…"
                            : String(format: "Downloading %.0f%%…", frac * 100)
                        self?.notifyProgress(frac * 0.9, label)
                    }
                )
            }

            notifyProgress(0.9, "Loading model…")
            kit = try await WhisperKit(modelFolder: modelFolder.path, verbose: false, download: false)
            isReady = true
            print("VTT: model ready")
            notifyProgress(1.0, "Ready")
        } catch {
            print("VTT: model load failed — \(error)")
        }
    }

    private func notifyProgress(_ fraction: Double, _ label: String) {
        let cb = onProgress
        DispatchQueue.main.async { cb?(fraction, label) }
    }

    // MARK: - Noise / hallucination filtering

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
                    sampleLength: 128,
                    withoutTimestamps: true
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
