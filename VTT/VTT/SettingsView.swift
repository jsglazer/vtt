import SwiftUI

struct SettingsView: View {
    @AppStorage("vtt.speechThreshold")   private var threshold: Double = 0.02
    @AppStorage("vtt.silenceTimeout")    private var silenceTimeout: Double = 0.4
    @AppStorage("vtt.minSpeechDuration") private var minSpeechDuration: Double = 0.5
    @AppStorage("vtt.autoNewLine")       private var autoNewLine: Bool = false
    @AppStorage("vtt.autoNewLineDelay")  private var autoNewLineDelay: Double = 2.0

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SliderRow(
                title: "Microphone Sensitivity",
                valueLabel: threshold < 0.015 ? "High" : threshold < 0.03 ? "Medium" : "Low",
                minLabel: "More sensitive",
                maxLabel: "Less sensitive",
                description: "How loud something must be to trigger recording",
                value: $threshold,
                range: 0.005...0.05
            )
            SliderRow(
                title: "Silence Timeout",
                valueLabel: String(format: "%.2f s", silenceTimeout),
                minLabel: "0.2 s",
                maxLabel: "1.2 s",
                description: "Wait after you stop speaking before transcribing",
                value: $silenceTimeout,
                range: 0.2...1.2
            )
            SliderRow(
                title: "Min Speech Duration",
                valueLabel: String(format: "%.2f s", minSpeechDuration),
                minLabel: "0.25 s",
                maxLabel: "1.5 s",
                description: "Ignore utterances shorter than this",
                value: $minSpeechDuration,
                range: 0.25...1.5
            )

            Divider()

            Toggle("Auto New Line", isOn: $autoNewLine)
            Text("Automatically insert a blank line after a period of silence")
                .font(.caption).foregroundColor(.secondary)

            if autoNewLine {
                SliderRow(
                    title: "Auto New Line Delay",
                    valueLabel: String(format: "%.1f s", autoNewLineDelay),
                    minLabel: "1.0 s",
                    maxLabel: "5.0 s",
                    description: "Insert \\n\\n after this much silence while recording",
                    value: $autoNewLineDelay,
                    range: 1.0...5.0
                )
            }

            Divider()

            HStack {
                Spacer()
                Button("Restore Defaults") {
                    threshold = 0.02
                    silenceTimeout = 0.4
                    minSpeechDuration = 0.5
                    autoNewLine = false
                    autoNewLineDelay = 2.0
                }
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

private struct SliderRow: View {
    let title: String
    let valueLabel: String
    let minLabel: String
    let maxLabel: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title).fontWeight(.medium)
                Spacer()
                Text(valueLabel)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 8) {
                Text(minLabel).font(.caption).foregroundColor(.secondary)
                Slider(value: $value, in: range)
                Text(maxLabel).font(.caption).foregroundColor(.secondary)
            }
            Text(description).font(.caption).foregroundColor(.secondary)
        }
    }
}
