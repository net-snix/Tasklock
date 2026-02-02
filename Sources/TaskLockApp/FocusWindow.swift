import SwiftUI
import AppKit
import Combine
import QuartzCore

@MainActor
final class FocusWindowController: NSWindowController, NSWindowDelegate {
    private var cancellables = Set<AnyCancellable>()
    private let viewModel: FocusViewModel
    private var closeButton: NSButton?
    private var trackingArea: NSTrackingArea?
    private var areTitleButtonsVisible = false
    private var hasInitialPositionBeenSet = false
    private var isInStartupPhase = true
    private var startupTimer: Task<Void, Never>?
    private var pendingHeight: CGFloat?
    private var heightUpdateTask: Task<Void, Never>?
    var onRequestHide: (() -> Void)?

    init(viewModel: FocusViewModel) {
        self.viewModel = viewModel

        let rootView = FocusWindowContent(viewModel: viewModel)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = true

        let initialRect = NSRect(
            x: 0,
            y: 0,
            width: Layout.windowWidth,
            height: viewModel.viewHeight
        )

        let window = FloatingWindow(
            contentRect: initialRect,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.title = "TaskLock"
        window.titlebarAppearsTransparent = true
        window.isOpaque = false
        window.hasShadow = true
        window.backgroundColor = .clear
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.isMovableByWindowBackground = true

        window.contentView = hostingView
        hostingView.frame = initialRect
        hostingView.autoresizingMask = [.width, .height]

        super.init(window: window)

        window.isReleasedWhenClosed = false

        window.delegate = self

        closeButton = window.standardWindowButton(.closeButton)
        closeButton?.alphaValue = 0
        closeButton?.isHidden = true
        if let miniButton = window.standardWindowButton(.miniaturizeButton) {
            miniButton.isHidden = true
            miniButton.isEnabled = false
            miniButton.alphaValue = 0
        }
        updateTitleButtonsVisibility(show: isMouseInsideWindow(), animated: false)
        setupMouseTracking(on: hostingView)

        if let zoom = window.standardWindowButton(.zoomButton) {
            zoom.isHidden = true
        }

        viewModel.$viewHeight
            .receive(on: RunLoop.main)
            .sink { [weak self] height in
                self?.scheduleWindowHeightUpdate(height)
            }
            .store(in: &cancellables)

        // Restore saved window position if available
        if let originX = viewModel.windowOriginX,
           let originY = viewModel.windowOriginY {
            var frame = window.frame
            frame.origin.x = originX
            frame.origin.y = originY
            window.setFrame(frame, display: false)
            hasInitialPositionBeenSet = true
        }

        // Start grace period timer to allow window to stabilize
        startupTimer = DelayedTask.after(milliseconds: Layout.Timing.startupDelay) { [weak self] in
            self?.isInStartupPhase = false
            self?.viewModel.endStartupPhase()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        onRequestHide?()
        return true
    }

    func windowDidBecomeKey(_ notification: Notification) {
        handleWindowActivationChange(isActive: true)
    }

    func windowDidResignKey(_ notification: Notification) {
        handleWindowActivationChange(isActive: false)
    }

    func windowDidBecomeMain(_ notification: Notification) {
        handleWindowActivationChange(isActive: true)
    }

    func windowDidResignMain(_ notification: Notification) {
        handleWindowActivationChange(isActive: false)
    }

    func windowDidMove(_ notification: Notification) {
        guard let window else { return }

        // Don't save position during startup phase
        guard !isInStartupPhase else {
            hasInitialPositionBeenSet = true
            return
        }

        hasInitialPositionBeenSet = true
        viewModel.saveWindowPosition(x: window.frame.origin.x, y: window.frame.origin.y)
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateTitleButtonsVisibility(show: true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        updateTitleButtonsVisibility(show: false)
    }

    private func updateWindowHeight(_ height: CGFloat) {
        guard let window else { return }
        let targetHeight = Layout.clampWindowHeight(height)
        var frame = window.frame

        // Anchor to top after startup so hover/content changes don't shift downward
        if hasInitialPositionBeenSet && !isInStartupPhase {
            let originalTop = frame.maxY
            frame.size.height = targetHeight
            frame.origin.y = originalTop - targetHeight
        } else {
            // During startup or initial sizing, just change height without moving
            frame.size.height = targetHeight
        }

        frame.size.width = Layout.windowWidth

        if let screenFrame = window.screen?.visibleFrame {
            let maxOriginY = screenFrame.maxY - frame.height
            let minOriginY = screenFrame.minY
            frame.origin.y = min(max(frame.origin.y, minOriginY), maxOriginY)
        }

        window.setFrame(frame, display: true, animate: false)
        if let contentView = window.contentView {
            contentView.frame = NSRect(origin: .zero, size: frame.size)
        }
    }

    private func scheduleWindowHeightUpdate(_ height: CGFloat) {
        pendingHeight = height
        guard heightUpdateTask == nil else { return }
        heightUpdateTask = Task { @MainActor in
            // Coalesce updates and avoid resizing during constraint passes.
            try? await Task.sleep(nanoseconds: 16_000_000)
            let nextHeight = pendingHeight
            pendingHeight = nil
            heightUpdateTask = nil
            guard let nextHeight else { return }
            updateWindowHeight(nextHeight)
        }
    }

    private func setupMouseTracking(on view: NSView) {
        if let trackingArea {
            view.removeTrackingArea(trackingArea)
        }

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        view.addTrackingArea(area)
        trackingArea = area
    }

    private func updateTitleButtonsVisibility(show: Bool, animated: Bool = true) {
        let buttons = [closeButton].compactMap { $0 }
        guard buttons.isEmpty == false else { return }

        if animated && show == areTitleButtonsVisible {
            return
        }

        areTitleButtonsVisible = show

        if animated {
            if show {
                buttons.forEach { $0.isHidden = false }
            }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Layout.Timing.titleButtonFade
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                buttons.forEach { button in
                    button.animator().alphaValue = show ? 1 : 0
                }
            } completionHandler: {
                guard show == false else { return }
                Task { @MainActor in
                    buttons.forEach { $0.isHidden = true }
                }
            }
        } else {
            buttons.forEach { button in
                button.isHidden = !show
                button.alphaValue = show ? 1 : 0
            }
        }
    }

    private func isMouseInsideWindow() -> Bool {
        guard let window else { return false }
        let mouseLocation = NSEvent.mouseLocation
        return window.frame.contains(mouseLocation)
    }

    private func handleWindowActivationChange(isActive: Bool) {
        if isActive == false {
            viewModel.commitEditing()
        }
    }
}

final class FloatingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
