import SwiftUI

struct FullScreenPulseView: View {
    let centerPoint: CGPoint
    let maxRadius: CGFloat
    let intensity: CGFloat
    let reduceMotion: Bool
    let onComplete: () -> Void

    @State private var wave1Progress: CGFloat = 0
    @State private var wave2Progress: CGFloat = 0
    @State private var wave3Progress: CGFloat = 0
    @State private var flashOpacity: CGFloat = 0

    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Initial flash effect at center
                Circle()
                    .fill(Color.accentColor.opacity(0.5 * flashOpacity * intensity))
                    .frame(width: 100, height: 100)
                    .position(centerPoint)

                if !reduceMotion {
                    // Wave 1 - First expanding ring
                    FullScreenWaveRing(
                        centerPoint: centerPoint,
                        progress: wave1Progress,
                        maxRadius: maxRadius,
                        delay: 0,
                        intensity: intensity
                    )

                    // Wave 2 - Second expanding ring (delayed)
                    FullScreenWaveRing(
                        centerPoint: centerPoint,
                        progress: wave2Progress,
                        maxRadius: maxRadius,
                        delay: 0.15,
                        intensity: intensity
                    )

                    // Wave 3 - Third expanding ring (more delayed)
                    FullScreenWaveRing(
                        centerPoint: centerPoint,
                        progress: wave3Progress,
                        maxRadius: maxRadius,
                        delay: 0.30,
                        intensity: intensity
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .drawingGroup()
        .onAppear {
            startAnimation()
        }
    }

    private func startAnimation() {
        // Initial flash
        withAnimation(Layout.Animation.flashFadeIn) {
            flashOpacity = 1
        }
        DelayedTask.after(milliseconds: Layout.Timing.waveFlashHold) {
            withAnimation(Layout.Animation.flashFadeOut) {
                flashOpacity = 0
            }
        }

        guard !reduceMotion else {
            scheduleCompletion()
            return
        }

        // Wave animations with duration scaled for larger radius
        let waveAnimation = Layout.Animation.overlayWaveExpansion(radius: maxRadius)

        // Wave 1 - Immediate start
        withAnimation(waveAnimation) {
            wave1Progress = 1
        }

        // Wave 2
        DelayedTask.after(milliseconds: Layout.Timing.wave2Delay) {
            withAnimation(waveAnimation) {
                wave2Progress = 1
            }
        }

        // Wave 3
        DelayedTask.after(milliseconds: Layout.Timing.wave3Delay) {
            withAnimation(waveAnimation) {
                wave3Progress = 1
            }
        }

        scheduleCompletion()
    }

    private func scheduleCompletion() {
        DelayedTask.after(milliseconds: Layout.PulseEffect.overlayDuration) {
            onComplete()
        }
    }
}

struct FullScreenWaveRing: View {
    let centerPoint: CGPoint
    let progress: CGFloat
    let maxRadius: CGFloat
    let delay: CGFloat
    let intensity: CGFloat

    var body: some View {
        let opacity = (Layout.PulseEffect.waveBaseOpacity - Layout.PulseEffect.waveBaseOpacity * progress)
            * max(0, 1 - delay * 0.3) * intensity
        let lineWidth = max(1, (Layout.PulseEffect.waveBaseLineWidth - Layout.PulseEffect.waveLineWidthRange * progress) * intensity)
        let currentRadius = maxRadius * progress

        Circle()
            .stroke(
                Color.accentColor.opacity(opacity),
                lineWidth: lineWidth
            )
            .frame(width: currentRadius * 2, height: currentRadius * 2)
            .position(centerPoint)
            .opacity((1 - progress) * intensity)
    }
}
