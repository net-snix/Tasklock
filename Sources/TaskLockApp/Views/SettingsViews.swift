import SwiftUI

// MARK: - Settings Scene (for standalone window)

struct SettingsScene: View {
    @ObservedObject var viewModel: FocusViewModel

    var body: some View {
        SettingsForm(viewModel: viewModel)
            .padding(24)
            .frame(width: 320)
    }
}

// MARK: - Settings Popover (for inline popover)

struct SettingsPopover: View {
    @ObservedObject var viewModel: FocusViewModel

    var body: some View {
        SettingsForm(viewModel: viewModel)
            .frame(width: 260)
    }
}

// MARK: - Settings Form

struct SettingsForm: View {
    @ObservedObject var viewModel: FocusViewModel
    @State private var intervalValue: Double
    @State private var unitSelection: TimeUnit

    private static let minInterval: Double = 5
    private static let maxInterval: Double = 10800

    init(viewModel: FocusViewModel) {
        self.viewModel = viewModel
        let initialValue = viewModel.pulseInterval
        _intervalValue = State(initialValue: initialValue)
        _unitSelection = State(initialValue: TimeUnit.preferred(for: initialValue))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pulse reminder")
                .font(.headline)

            HStack(spacing: 10) {
                Text("Every")
                    .font(.body)
                TextField(
                    "Value",
                    value: durationValueBinding,
                    format: .number.precision(.fractionLength(0...2))
                )
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                .help("Enter how often the pulse should appear")

                Picker("", selection: $unitSelection) {
                    ForEach(TimeUnit.allCases) { unit in
                        Text(unit.label).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .frame(minWidth: 110)
            }

            HStack(spacing: 8) {
                Picker("Sound effect", selection: $viewModel.selectedSoundEffectID) {
                    if viewModel.soundEffects.isEmpty {
                        Text("None available").tag("")
                    } else {
                        ForEach(viewModel.soundEffects) { effect in
                            Text(effect.displayName).tag(effect.id)
                        }
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(viewModel.soundEffects.isEmpty)

                Button {
                    viewModel.previewSelectedSound()
                } label: {
                    Image(systemName: "play.fill")
                }
                .buttonStyle(.bordered)
                .help("Preview the selected sound")
                .disabled(viewModel.soundEffects.isEmpty || viewModel.selectedSoundEffectID == "none")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pulse intensity")
                        .font(.body)
                    Spacer()
                    Text("\(Int(viewModel.pulseIntensity * 100))%")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $viewModel.pulseIntensity, in: 0.0...1.0, step: 0.05)
                    .help("Control how dramatic the pulse animation appears")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pulse range")
                        .font(.body)
                    Spacer()
                    Text(pulseRangeLabel)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                Slider(value: $viewModel.pulseRange, in: 0.0...1.0, step: 0.1)
                    .help("Control how far the pulse extends across your screen")
            }

            Divider()

            Button(role: .none) {
                viewModel.resetDefaults()
                intervalValue = viewModel.pulseInterval
                unitSelection = TimeUnit.preferred(for: viewModel.pulseInterval)
            } label: {
                Label("Reset defaults", systemImage: "arrow.uturn.left")
            }
            .buttonStyle(.bordered)
        }
        .onReceive(viewModel.$pulseInterval) { newValue in
            let clamped = clampInterval(newValue)
            guard abs(clamped - intervalValue) > 0.5 else { return }
            intervalValue = clamped
            unitSelection = TimeUnit.preferred(for: clamped)
        }
    }

    private var durationValueBinding: Binding<Double> {
        Binding(
            get: { intervalValue / unitSelection.multiplier },
            set: { newValue in
                guard newValue.isFinite else { return }
                updateInterval(to: newValue * unitSelection.multiplier)
            }
        )
    }

    private func updateInterval(to seconds: Double) {
        let clamped = clampInterval(seconds)
        intervalValue = clamped
        viewModel.pulseInterval = clamped
    }

    private func clampInterval(_ value: Double) -> Double {
        min(max(value, Self.minInterval), Self.maxInterval)
    }

    private var pulseRangeLabel: String {
        if viewModel.pulseRange == 0 {
            return "Window only"
        } else if viewModel.pulseRange < 0.5 {
            return "Partial"
        } else if viewModel.pulseRange < 1.0 {
            return "Extended"
        } else {
            return "Full screen"
        }
    }
}

// MARK: - Time Unit

enum TimeUnit: String, CaseIterable, Identifiable {
    case seconds
    case minutes
    case hours

    var id: String { rawValue }

    var label: String {
        switch self {
        case .seconds: return "Seconds"
        case .minutes: return "Minutes"
        case .hours: return "Hours"
        }
    }

    var multiplier: Double {
        switch self {
        case .seconds: return 1
        case .minutes: return 60
        case .hours: return 3600
        }
    }

    static func preferred(for seconds: Double) -> TimeUnit {
        if seconds >= 3600 {
            return .hours
        } else if seconds >= 60 {
            return .minutes
        }
        return .seconds
    }
}
