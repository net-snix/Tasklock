import SwiftUI
import AppKit
import Combine

@main
struct TaskLockApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsScene(viewModel: appDelegate.viewModel)
        }
        .windowResizability(.contentMinSize)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let viewModel = FocusViewModel()
    private var windowController: FocusWindowController?
    private var statusItem: NSStatusItem?
    private var pulseOverlayController: PulseOverlayWindowController?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        setupStatusItem()
        createWindowIfNeeded()
        setupPulseOverlay()
        showWindow()
    }

    private func setupPulseOverlay() {
        pulseOverlayController = PulseOverlayWindowController()

        // Subscribe to pulse events for full-screen overlay
        viewModel.$pulseEventID
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.triggerFullScreenPulse()
            }
            .store(in: &cancellables)
    }

    private func triggerFullScreenPulse() {
        guard viewModel.pulseRange > 0 else { return }
        guard viewModel.pulseIntensity > 0 else { return }
        guard let window = windowController?.window else { return }

        // Calculate center point (center of main window in screen coordinates)
        let windowCenter = CGPoint(
            x: window.frame.midX,
            y: window.frame.midY
        )

        let maxRadius = PulseOverlayWindowController.calculateMaxRadius(
            range: viewModel.pulseRange,
            centerPoint: windowCenter,
            screen: window.screen
        )

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion

        pulseOverlayController?.showPulse(
            centerPoint: windowCenter,
            maxRadius: maxRadius,
            intensity: viewModel.pulseIntensity,
            reduceMotion: reduceMotion,
            on: window.screen
        )
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard flag == false else { return true }
        showWindow()
        return true
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let baseImage = NSImage(
                systemSymbolName: "scope",
                accessibilityDescription: "TaskLock"
            )
            let image = baseImage?.tinted(with: .white)
            button.image = image
            button.contentTintColor = nil
            button.appearsDisabled = false
            button.target = self
            button.action = #selector(toggleWindowFromStatusItem)
            button.toolTip = "Show or hide TaskLock"
        }
        statusItem = item
    }

    private func createWindowIfNeeded() {
        guard windowController == nil else { return }
        let controller = FocusWindowController(viewModel: viewModel)
        controller.onRequestHide = { [weak self] in
            self?.hideWindow()
        }
        windowController = controller
    }

    @objc private func toggleWindowFromStatusItem() {
        guard let window = windowController?.window else {
            showWindow()
            return
        }
        if window.isVisible {
            hideWindow()
        } else {
            showWindow()
        }
    }

    private func showWindow() {
        createWindowIfNeeded()
        guard let controller = windowController else { return }
        controller.showWindow(self)
        controller.window?.makeKeyAndOrderFront(self)

        // Center window ONLY if no saved position exists
        if viewModel.windowOriginX == nil {
            controller.window?.center()
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        viewModel.beginEditing()
        viewModel.setPulseActive(true)
        updateStatusItemAppearance(isVisible: true)
    }

    private func hideWindow() {
        guard let window = windowController?.window else { return }
        window.orderOut(self)
        viewModel.commitEditing()
        viewModel.flushWindowPositionSave()
        viewModel.setPulseActive(false)
        updateStatusItemAppearance(isVisible: false)
    }

    private func updateStatusItemAppearance(isVisible: Bool) {
        statusItem?.button?.alphaValue = isVisible ? 1 : 0.65
    }
}
