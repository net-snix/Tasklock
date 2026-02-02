import SwiftUI
import AppKit
import Combine

struct FocusWindowContent: View {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @ObservedObject var viewModel: FocusViewModel
    @State private var noteHeight: CGFloat
    @State private var isSettingsPresented = false
    @State private var isPulsing = false
    @State private var isHovering = false
    @State private var editorShouldBeFocused = true
    @State private var pulseVisualID = UUID()
    @State private var pulseEnvelope: CGFloat = 0
    @State private var hasHandledInitialPulse = false

    init(viewModel: FocusViewModel) {
        self.viewModel = viewModel
        _noteHeight = State(initialValue: viewModel.savedTextHeight)
    }

    var body: some View {
        content
            .frame(width: Layout.windowWidth)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ViewHeightPreferenceKey.self, value: proxy.size.height)
                }
            )
            .onPreferenceChange(ViewHeightPreferenceKey.self) { height in
                viewModel.updateContentHeight(height)
            }
            .onReceive(viewModel.$pulseEventID) { newID in
                pulseVisualID = newID
                guard hasHandledInitialPulse else {
                    hasHandledInitialPulse = true
                    return
                }
                triggerPulse()
                animatePulseEnvelope()
            }
            .onReceive(viewModel.$requestedEditorFocusID) { _ in
                editorShouldBeFocused = true
            }
            .onReceive(viewModel.$requestedEditorBlurID) { _ in
                editorShouldBeFocused = false
            }
    }

    private var content: some View {
        let showHeader = isHovering || isSettingsPresented

        return ZStack {
            // Multi-wave pulse rings for attention-grabbing effect
            MultiwavePulseView(intensity: viewModel.pulseIntensity, reduceMotion: reduceMotion)
                .id(pulseVisualID)
                .padding(viewModel.isEditing ? Layout.Metrics.pulsePaddingEditing : Layout.Metrics.pulsePaddingStandard)
                .allowsHitTesting(false)

            VStack(alignment: .leading, spacing: 0) {
                if showHeader {
                    header
                        .transition(
                            .asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .top)),
                                removal: .opacity
                            )
                        )
                        .padding(.bottom, Layout.Metrics.paddingHeaderBottom)
                }
                noteCard
            }
            .padding(.horizontal, Layout.Metrics.paddingContentHorizontal)
            .padding(.vertical, Layout.Metrics.paddingContentVertical)
            .background(
                RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusLarge, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusLarge, style: .continuous)
                            .strokeBorder(
                                Color.white.opacity(
                                    Layout.PulseEffect.borderBaseOpacity +
                                    Layout.PulseEffect.borderMaxOpacity * pulseEnvelope * viewModel.pulseIntensity
                                ),
                                lineWidth: 1 + 3 * pulseEnvelope * viewModel.pulseIntensity
                            )
                            .blendMode(.screen)
                    )
                    .shadow(color: Color.black.opacity(0.08), radius: 8, y: 3)
            )
            .scaleEffect(reduceMotion ? 1.0 : (1 + Layout.PulseEffect.scaleAmplitude * pulseEnvelope * viewModel.pulseIntensity))
            .rotationEffect(.degrees(reduceMotion ? 0 : (Layout.PulseEffect.rotationMultiplier * pulseEnvelope * viewModel.pulseIntensity * sin(pulseEnvelope * .pi))))
            .shadow(
                color: Color.accentColor.opacity(0.50 * pulseEnvelope * viewModel.pulseIntensity),
                radius: (reduceMotion ? 10 : 25) * pulseEnvelope * viewModel.pulseIntensity,
                y: (reduceMotion ? 0 : 4) * pulseEnvelope * viewModel.pulseIntensity
            )
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .onHover { hovering in
            withAnimation(Layout.Animation.hoverTransition) {
                isHovering = hovering
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Label {
                Text("TaskLock")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "scope")
                    .symbolVariant(.circle)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .labelStyle(.titleAndIcon)

            Spacer()

            Button {
                isSettingsPresented.toggle()
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(width: 32, height: 32)
                    .contentShape(RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusSmall, style: .continuous))
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusSmall, style: .continuous)
                    .fill(.regularMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusSmall, style: .continuous)
                    .strokeBorder(.white.opacity(0.25))
            )
            .shadow(color: Color.black.opacity(0.10), radius: 4, y: 2)
            .popover(isPresented: $isSettingsPresented, arrowEdge: .top) {
                SettingsPopover(viewModel: viewModel)
                    .padding(16)
            }
        }
    }

    private var noteCard: some View {
        FocusTextView(
            text: $viewModel.focusText,
            isEditable: viewModel.isEditing,
            shouldBecomeFirstResponder: $editorShouldBeFocused,
            onHeightChange: { newHeight in
                let clamped = Layout.clampTextHeight(newHeight)
                guard abs(clamped - noteHeight) > 0.5 else { return }
                noteHeight = clamped
                viewModel.updateTextHeightCache(clamped)
            },
            onCommit: viewModel.commitEditing
        )
        .frame(maxWidth: .infinity)
        .frame(height: noteHeight)
        .padding(.vertical, Layout.Metrics.paddingNoteVertical)
        .padding(.horizontal, Layout.Metrics.paddingNoteHorizontal)
        .background(
            RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusMedium, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusMedium, style: .continuous)
                        .stroke(
                            Color.accentColor.opacity(isPulsing ? 0.85 : (viewModel.isEditing || isHovering ? 0.55 : 0.28)),
                            lineWidth: viewModel.isEditing ? 1.6 : 1.2
                        )
                        .animation(Layout.Animation.borderTransition, value: isPulsing)
                )
                .shadow(color: Color.black.opacity(viewModel.isEditing ? 0.15 : 0.10), radius: 10, y: 4)
        )
        .contentShape(RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusMedium, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusMedium, style: .continuous)
                .fill(Color.clear)
                .contentShape(RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusMedium, style: .continuous))
                .allowsHitTesting(viewModel.isEditing == false)
                .onTapGesture {
                    guard viewModel.isEditing == false else { return }
                    viewModel.beginEditing()
                }
        )
    }

    private func triggerPulse() {
        guard isPulsing == false else { return }
        isPulsing = true
        DelayedTask.after(milliseconds: Layout.Timing.pulseDuration) {
            isPulsing = false
        }
    }

    private func animatePulseEnvelope() {
        withAnimation(Layout.Animation.pulseSpring) {
            pulseEnvelope = 1
        }
        DelayedTask.after(milliseconds: Layout.Timing.pulseEnvelopeDecayDelay) {
            withAnimation(Layout.Animation.pulseDecay) {
                pulseEnvelope = 0
            }
        }
    }
}
