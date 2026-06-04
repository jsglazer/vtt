import SwiftUI

struct SettingsView: View {
    @AppStorage("vtt.speechThreshold")   private var threshold: Double = 0.02
    @AppStorage("vtt.silenceTimeout")    private var silenceTimeout: Double = 0.5
    @AppStorage("vtt.minSpeechDuration") private var minSpeechDuration: Double = 0.5
    @AppStorage("vtt.autoNewLine")       private var autoNewLine: Bool = false
    @AppStorage("vtt.autoNewLineDelay")  private var autoNewLineDelay: Double = 2.0
    @AppStorage("vtt.showWaveform")      private var showWaveform: Bool = true

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
                valueLabel: stepLabel(silenceTimeout),
                minLabel: "0 s",
                maxLabel: "5 s",
                description: "Wait after you stop speaking before transcribing",
                value: $silenceTimeout,
                range: 0...5,
                step: 0.25
            )
            SliderRow(
                title: "Min Speech Duration",
                valueLabel: stepLabel(minSpeechDuration),
                minLabel: "0 s",
                maxLabel: "5 s",
                description: "Ignore utterances shorter than this",
                value: $minSpeechDuration,
                range: 0...5,
                step: 0.25
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

            Toggle("Show Waveform", isOn: $showWaveform)
            Text("Animated audio bars to the left of the menu bar icon while recording")
                .font(.caption).foregroundColor(.secondary)

            Divider()

            HStack {
                Spacer()
                Button("Restore Defaults") {
                    threshold = 0.02
                    silenceTimeout = 0.5
                    minSpeechDuration = 0.5
                    autoNewLine = false
                    autoNewLineDelay = 2.0
                    showWaveform = true
                }
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}

// Formats a stepped time value: whole seconds as "1 s", fractional as "0.25 s"
private func stepLabel(_ v: Double) -> String {
    v == v.rounded() ? "\(Int(v)) s" : String(format: "%.2g s", v)
}

private struct SliderRow: View {
    let title: String
    let valueLabel: String
    let minLabel: String
    let maxLabel: String
    let description: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil

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
                if let step {
                    Slider(value: $value, in: range, step: step)
                } else {
                    Slider(value: $value, in: range)
                }
                Text(maxLabel).font(.caption).foregroundColor(.secondary)
            }
            Text(description).font(.caption).foregroundColor(.secondary)
        }
    }
}
