import SwiftUI
import AppKit

struct FocusTextView: NSViewRepresentable {
    @Binding var text: String
    var isEditable: Bool
    @Binding var shouldBecomeFirstResponder: Bool
    var onHeightChange: (CGFloat) -> Void
    var onCommit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isEditable: isEditable,
            shouldBecomeFirstResponder: $shouldBecomeFirstResponder,
            onHeightChange: onHeightChange,
            onCommit: onCommit
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = true
        scrollView.documentView = context.coordinator.textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.textBinding = $text
        coordinator.onHeightChange = onHeightChange
        coordinator.onCommit = onCommit
        coordinator.isEditable = isEditable
        coordinator.focusBinding = $shouldBecomeFirstResponder

        if coordinator.textView.string != text {
            coordinator.textView.string = text
            coordinator.markNeedsHeightUpdate()
        }

        coordinator.applyEditorState()
        coordinator.updateTextContainerWidth(nsView.bounds.width)
        coordinator.updateHeightIfNeeded()
        coordinator.syncFocusState()
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var textBinding: Binding<String>
        var focusBinding: Binding<Bool>
        var onHeightChange: (CGFloat) -> Void
        var onCommit: () -> Void
        var isEditable: Bool
        let textView: NSTextView
        private var lastMeasuredWidth: CGFloat = 0
        private var lastReportedHeight: CGFloat = Layout.minTextHeight
        private var needsHeightUpdate = true
        private let heightEpsilon: CGFloat = 0.5

        init(
            text: Binding<String>,
            isEditable: Bool,
            shouldBecomeFirstResponder: Binding<Bool>,
            onHeightChange: @escaping (CGFloat) -> Void,
            onCommit: @escaping () -> Void
        ) {
            self.textBinding = text
            self.isEditable = isEditable
            self.focusBinding = shouldBecomeFirstResponder
            self.onHeightChange = onHeightChange
            self.onCommit = onCommit
            self.textView = NSTextView(frame: .zero)
            super.init()
            configureTextView()
        }

        private func configureTextView() {
            textView.delegate = self
            textView.isRichText = false
            textView.isEditable = true
            textView.isSelectable = true
            textView.isHorizontallyResizable = false
            textView.isVerticallyResizable = true
            textView.drawsBackground = false
            textView.backgroundColor = .clear
            textView.font = .systemFont(ofSize: 18, weight: .semibold)
            textView.textColor = NSColor.labelColor
            textView.textContainerInset = NSSize(width: 2, height: 6)
            textView.textContainer?.lineFragmentPadding = 0
            textView.textContainer?.widthTracksTextView = true
            textView.allowsUndo = true
            textView.usesFindPanel = true
            textView.insertionPointColor = NSColor.controlAccentColor
        }

        func applyEditorState() {
            textView.isEditable = isEditable
            textView.textColor = isEditable ? NSColor.labelColor : NSColor.labelColor.withAlphaComponent(0.9)
            if isEditable == false {
                textView.undoManager?.removeAllActions()
            }
        }

        func syncFocusState() {
            guard let window = textView.window else { return }
            if focusBinding.wrappedValue, window.firstResponder !== textView, isEditable {
                window.makeFirstResponder(textView)
            } else if focusBinding.wrappedValue == false, window.firstResponder === textView {
                window.makeFirstResponder(nil)
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            focusBinding.wrappedValue = true
        }

        func textDidEndEditing(_ notification: Notification) {
            focusBinding.wrappedValue = false
        }

        func textDidChange(_ notification: Notification) {
            textBinding.wrappedValue = textView.string
            markNeedsHeightUpdate()
            updateHeightIfNeeded(force: true)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard isEditable,
                  commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }
            if let modifiers = NSApp.currentEvent?.modifierFlags, modifiers.contains(.shift) {
                return false
            }
            onCommit()
            focusBinding.wrappedValue = false
            return true
        }

        func updateTextContainerWidth(_ width: CGFloat) {
            guard width > 0 else { return }
            if abs(width - lastMeasuredWidth) <= 0.5 {
                return
            }
            lastMeasuredWidth = width
            textView.textContainer?.containerSize = NSSize(
                width: width,
                height: .greatestFiniteMagnitude
            )
            markNeedsHeightUpdate()
        }

        func updateHeightIfNeeded(force: Bool = false) {
            guard force || needsHeightUpdate else { return }
            needsHeightUpdate = false
            guard let layoutManager = textView.layoutManager,
                  let container = textView.textContainer else {
                reportHeightIfNeeded(Layout.minTextHeight)
                return
            }
            layoutManager.ensureLayout(for: container)
            var usedRect = layoutManager.usedRect(for: container)
            usedRect.size.height += textView.textContainerInset.height * 2
            let adjustedHeight = max(Layout.minTextHeight, usedRect.height)
            reportHeightIfNeeded(adjustedHeight)
        }

        func markNeedsHeightUpdate() {
            needsHeightUpdate = true
        }

        private func reportHeightIfNeeded(_ newHeight: CGFloat) {
            guard abs(newHeight - lastReportedHeight) > heightEpsilon else { return }
            lastReportedHeight = newHeight
            onHeightChange(newHeight)
        }
    }
}
