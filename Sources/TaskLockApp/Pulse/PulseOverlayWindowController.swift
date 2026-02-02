import AppKit
import SwiftUI

@MainActor
final class PulseOverlayWindowController {
    private var overlayWindow: NSWindow?

    func showPulse(
        centerPoint: CGPoint,
        maxRadius: CGFloat,
        intensity: CGFloat,
        reduceMotion: Bool,
        on screen: NSScreen?
    ) {
        dismissExisting()

        guard let targetScreen = screen ?? NSScreen.main else { return }
        let screenFrame = targetScreen.frame

        // Create transparent overlay window
        let window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: targetScreen
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Convert center point to window coordinates (flip Y for SwiftUI)
        let windowCenter = CGPoint(
            x: centerPoint.x - screenFrame.origin.x,
            y: screenFrame.height - (centerPoint.y - screenFrame.origin.y)
        )

        let pulseView = FullScreenPulseView(
            centerPoint: windowCenter,
            maxRadius: maxRadius,
            intensity: intensity,
            reduceMotion: reduceMotion,
            onComplete: { [weak self] in
                self?.dismiss()
            }
        )

        let hostingView = NSHostingView(rootView: pulseView)
        hostingView.frame = NSRect(origin: .zero, size: screenFrame.size)
        window.contentView = hostingView

        // Fade in
        window.alphaValue = 0
        window.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.PulseEffect.overlayFadeInDuration
            window.animator().alphaValue = 1
        }

        overlayWindow = window
    }

    func dismiss() {
        guard let window = overlayWindow else { return }
        overlayWindow = nil

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Layout.PulseEffect.overlayFadeOutDuration
            window.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                window.orderOut(nil)
            }
        }
    }

    private func dismissExisting() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
    }

    /// Calculate the maximum pulse radius based on range setting (0-1) and screen size
    static func calculateMaxRadius(
        range: CGFloat,
        centerPoint: CGPoint,
        screen: NSScreen?
    ) -> CGFloat {
        guard range > 0 else { return 0 }
        guard let screen = screen ?? NSScreen.main else { return Layout.PulseEffect.minPulseRadius }

        let screenFrame = screen.frame

        // Calculate distance to farthest corner from center point
        let corners = [
            CGPoint(x: screenFrame.minX, y: screenFrame.minY),
            CGPoint(x: screenFrame.maxX, y: screenFrame.minY),
            CGPoint(x: screenFrame.minX, y: screenFrame.maxY),
            CGPoint(x: screenFrame.maxX, y: screenFrame.maxY)
        ]

        let maxCornerDistance = corners.map { corner in
            hypot(corner.x - centerPoint.x, corner.y - centerPoint.y)
        }.max() ?? screenFrame.width

        // Interpolate between min radius and full-screen radius based on range
        return Layout.PulseEffect.minPulseRadius + (maxCornerDistance - Layout.PulseEffect.minPulseRadius) * range
    }
}
