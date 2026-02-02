import SwiftUI
import CoreGraphics

enum Layout {
    // Window & Text Constraints
    static let windowWidth: CGFloat = 360
    static let minWindowHeight: CGFloat = 86
    static let maxWindowHeight: CGFloat = 520
    static let defaultWindowHeight: CGFloat = 140

    static let minTextHeight: CGFloat = 34
    static let maxTextHeight: CGFloat = 420
    static let windowChromePadding: CGFloat = defaultWindowHeight - minTextHeight

    static func clampWindowHeight(_ value: CGFloat) -> CGFloat {
        max(minWindowHeight, min(maxWindowHeight, value))
    }

    static func clampTextHeight(_ value: CGFloat) -> CGFloat {
        max(minTextHeight, min(maxTextHeight, value))
    }

    static func estimatedWindowHeight(forTextHeight textHeight: CGFloat) -> CGFloat {
        clampWindowHeight(textHeight + windowChromePadding)
    }

    // Design System
    enum Metrics {
        static let cornerRadiusSmall: CGFloat = 12
        static let cornerRadiusMedium: CGFloat = 22
        static let cornerRadiusLarge: CGFloat = 26
        static let cornerRadiusRing: CGFloat = 30

        static let paddingContentHorizontal: CGFloat = 20
        static let paddingContentVertical: CGFloat = 16
        static let paddingNoteHorizontal: CGFloat = 18
        static let paddingNoteVertical: CGFloat = 10
        static let paddingHeaderBottom: CGFloat = 10
        
        static let pulsePaddingEditing: CGFloat = 6
        static let pulsePaddingStandard: CGFloat = 2
    }

    enum Animation {
        static let editingTransition = SwiftUI.Animation.spring(response: 0.32, dampingFraction: 0.85, blendDuration: 0.2)
        static let hoverTransition = SwiftUI.Animation.easeInOut(duration: 0.18)
        static let borderTransition = SwiftUI.Animation.easeInOut(duration: 0.35)

        static let pulseSpring = SwiftUI.Animation.interpolatingSpring(stiffness: 220, damping: 16)
        static let pulseDecay = SwiftUI.Animation.easeOut(duration: 0.35)

        static let waveExpansion = SwiftUI.Animation.easeOut(duration: 1.2)
        static let flashFadeIn = SwiftUI.Animation.easeOut(duration: 0.1)
        static let flashFadeOut = SwiftUI.Animation.easeOut(duration: 0.2)

        // Full-screen overlay animations
        static func overlayWaveExpansion(radius: CGFloat) -> SwiftUI.Animation {
            .easeOut(duration: 1.2 + Double(radius / 1000) * 0.3)
        }
    }
    
    enum Timing {
        static let pulseDuration: UInt64 = 420 // ms
        static let pulseEnvelopeDecayDelay: UInt64 = 520 // ms

        static let waveFlashHold: UInt64 = 100 // ms
        static let wave2Delay: UInt64 = 150 // ms
        static let wave3Delay: UInt64 = 300 // ms

        static let titleButtonFade: Double = 0.2 // seconds
        static let startupDelay: UInt64 = 500 // ms
    }

    // MARK: - Pulse Animation Constants
    enum PulseEffect {
        // Border glow opacity
        static let borderBaseOpacity: CGFloat = 0.28
        static let borderMaxOpacity: CGFloat = 0.40

        // Scale and rotation effects
        static let scaleAmplitude: CGFloat = 0.06
        static let rotationMultiplier: CGFloat = 2.0

        // Wave ring animation
        static let waveBaseOpacity: CGFloat = 0.60
        static let waveBaseLineWidth: CGFloat = 4.0
        static let waveLineWidthRange: CGFloat = 3.5
        static let waveBaseScale: CGFloat = 0.85
        static let waveScaleRange: CGFloat = 0.90

        // Full-screen overlay pulse
        static let overlayFadeInDuration: Double = 0.08
        static let overlayFadeOutDuration: Double = 0.4
        static let overlayDuration: UInt64 = 1400
        static let minPulseRadius: CGFloat = 200
    }

    // MARK: - Window Controller Constants
    enum WindowController {
        static let initialYOffset: CGFloat = 100
    }
}
