import SwiftUI

// MARK: - Multi-wave Pulse View

struct MultiwavePulseView: View {
    let intensity: CGFloat
    let reduceMotion: Bool
    @State private var wave1Progress: CGFloat = 0
    @State private var wave2Progress: CGFloat = 0
    @State private var wave3Progress: CGFloat = 0
    @State private var flashOpacity: CGFloat = 0

    var body: some View {
        ZStack {
            // Initial flash effect for immediate attention
            RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusRing, style: .continuous)
                .fill(Color.accentColor.opacity(0.6 * flashOpacity * intensity))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !reduceMotion {
                // Wave 1 - First expanding ring
                WaveRing(progress: wave1Progress, delay: 0, intensity: intensity)

                // Wave 2 - Second expanding ring (delayed)
                WaveRing(progress: wave2Progress, delay: 0.15, intensity: intensity)

                // Wave 3 - Third expanding ring (more delayed)
                WaveRing(progress: wave3Progress, delay: 0.30, intensity: intensity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
        .compositingGroup()
        .onAppear {
            // Reset all states
            wave1Progress = 0
            wave2Progress = 0
            wave3Progress = 0
            flashOpacity = 0

            // Initial flash
            withAnimation(Layout.Animation.flashFadeIn) {
                flashOpacity = 1
            }
            DelayedTask.after(milliseconds: Layout.Timing.waveFlashHold) {
                withAnimation(Layout.Animation.flashFadeOut) {
                    flashOpacity = 0
                }
            }

            guard !reduceMotion else { return }

            // Wave 1 - Immediate start
            withAnimation(Layout.Animation.waveExpansion) {
                wave1Progress = 1
            }

            // Wave 2
            DelayedTask.after(milliseconds: Layout.Timing.wave2Delay) {
                withAnimation(Layout.Animation.waveExpansion) {
                    wave2Progress = 1
                }
            }

            // Wave 3
            DelayedTask.after(milliseconds: Layout.Timing.wave3Delay) {
                withAnimation(Layout.Animation.waveExpansion) {
                    wave3Progress = 1
                }
            }
        }
    }
}

// MARK: - Wave Ring

struct WaveRing: View {
    let progress: CGFloat
    let delay: CGFloat
    let intensity: CGFloat

    var body: some View {
        let opacity = (Layout.PulseEffect.waveBaseOpacity - Layout.PulseEffect.waveBaseOpacity * progress) * max(0, 1 - delay * 0.3) * intensity
        let lineWidth = max(0.5, (Layout.PulseEffect.waveBaseLineWidth - Layout.PulseEffect.waveLineWidthRange * progress) * intensity)
        let scale = Layout.PulseEffect.waveBaseScale + Layout.PulseEffect.waveScaleRange * progress * intensity

        return RoundedRectangle(cornerRadius: Layout.Metrics.cornerRadiusRing, style: .continuous)
            .stroke(
                Color.accentColor.opacity(opacity),
                lineWidth: lineWidth
            )
            .scaleEffect(scale)
            .opacity((1 - progress) * intensity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
