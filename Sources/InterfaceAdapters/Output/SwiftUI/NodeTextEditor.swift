// Background: Node inline editing needs AppKit key handling not exposed by SwiftUI text components.
// Responsibility: Provide an NSTextView bridge with Enter commit, Escape cancel, and Option+Enter newline behavior.
import AppKit
import SwiftUI

/// Initial cursor position when the inline editor first receives focus.
enum NodeTextEditorInitialCursorPlacement: Equatable {
    case start
    case end
}

/// Inline editor used for canvas node text editing.
struct NodeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let selectAllOnFirstFocus: Bool
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
    let onMeasuredHeightChange: (CGFloat) -> Void
    let onCommit: () -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> NodeTextEditorTextView {
        let textView = NodeTextEditorTextView()
        textView.delegate = context.coordinator
        textView.onCommit = onCommit
        textView.onCancel = onCancel
        configureTextViewAppearance(textView)
        return textView
    }

    func updateNSView(_ nsView: NodeTextEditorTextView, context: Context) {
        if nsView.string != text {
            nsView.string = text
        }
        nsView.onCommit = onCommit
        nsView.onCancel = onCancel
        nsView.typingAttributes[.foregroundColor] = NSColor.labelColor
        nsView.typingAttributes[.font] = nsView.font ?? NodeTextStyle.font
        nsView.textColor = .labelColor
        nsView.insertionPointColor = .labelColor
        focusEditorIfNeeded(nsView, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            selectAllOnFirstFocus: selectAllOnFirstFocus,
            initialCursorPlacement: initialCursorPlacement,
            onMeasuredHeightChange: onMeasuredHeightChange
        )
    }
}

extension NodeTextEditor {
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        let selectAllOnFirstFocus: Bool
        let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
        let onMeasuredHeightChange: (CGFloat) -> Void
        var hasFocusedEditor: Bool = false
        /// Monotonic token used to cancel stale focus retries from older update cycles.
        var focusRequestID: UInt64 = 0

        init(
            text: Binding<String>,
            selectAllOnFirstFocus: Bool,
            initialCursorPlacement: NodeTextEditorInitialCursorPlacement,
            onMeasuredHeightChange: @escaping (CGFloat) -> Void
        ) {
            self.text = text
            self.selectAllOnFirstFocus = selectAllOnFirstFocus
            self.initialCursorPlacement = initialCursorPlacement
            self.onMeasuredHeightChange = onMeasuredHeightChange
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text.wrappedValue = textView.string
            pushMeasuredHeightIfReady(from: textView)
        }

        func pushMeasuredHeightIfReady(from textView: NSTextView) {
            guard textView.bounds.width > 1 else {
                return
            }
            onMeasuredHeightChange(NodeTextEditorTextViewMeasurement.nodeHeight(for: textView))
        }
    }

    private func configureTextViewAppearance(_ textView: NodeTextEditorTextView) {
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: NodeTextStyle.fontSize, weight: NodeTextStyle.fontWeight)
        textView.textColor = .labelColor
        textView.insertionPointColor = .labelColor
        textView.isRichText = false
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.typingAttributes = [
            .foregroundColor: NSColor.labelColor,
            .font: textView.font ?? NodeTextStyle.font,
        ]
    }

    private func focusEditorIfNeeded(
        _ textView: NodeTextEditorTextView,
        coordinator: Coordinator
    ) {
        // Cancel outstanding retries and start a new focus cycle for the latest editor state.
        coordinator.focusRequestID &+= 1
        let requestID = coordinator.focusRequestID
        attemptFocus(
            textView,
            coordinator: coordinator,
            requestID: requestID,
            remainingAttempts: 20
        )
    }

    private func attemptFocus(
        _ textView: NodeTextEditorTextView,
        coordinator: Coordinator,
        requestID: UInt64,
        remainingAttempts: Int
    ) {
        // Retry with a short delay because first responder handoff can race with SwiftUI view updates.
        let delay: DispatchTimeInterval = remainingAttempts == 20 ? .milliseconds(0) : .milliseconds(10)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard coordinator.focusRequestID == requestID else {
                return
            }
            guard let window = textView.window else {
                guard remainingAttempts > 1 else {
                    return
                }
                attemptFocus(
                    textView,
                    coordinator: coordinator,
                    requestID: requestID,
                    remainingAttempts: remainingAttempts - 1
                )
                return
            }

            guard window.firstResponder !== textView else {
                coordinator.hasFocusedEditor = true
                return
            }

            let becameFirstResponder = window.makeFirstResponder(textView)
            guard becameFirstResponder else {
                guard remainingAttempts > 1 else {
                    return
                }
                attemptFocus(
                    textView,
                    coordinator: coordinator,
                    requestID: requestID,
                    remainingAttempts: remainingAttempts - 1
                )
                return
            }

            if coordinator.selectAllOnFirstFocus, !coordinator.hasFocusedEditor {
                textView.selectAll(nil)
            } else if !coordinator.hasFocusedEditor {
                placeInitialCursor(textView, placement: coordinator.initialCursorPlacement)
            }
            coordinator.pushMeasuredHeightIfReady(from: textView)
            coordinator.hasFocusedEditor = true
        }
    }

    private func placeInitialCursor(
        _ textView: NodeTextEditorTextView,
        placement: NodeTextEditorInitialCursorPlacement
    ) {
        let textLength = (textView.string as NSString).length
        let location: Int
        switch placement {
        case .start:
            location = 0
        case .end:
            location = textLength
        }
        textView.setSelectedRange(NSRange(location: location, length: 0))
    }
}

private enum NodeTextEditorTextViewMeasurement {
    static func nodeHeight(
        for textView: NSTextView,
        outerVerticalPadding: CGFloat = 6,
        verticalSafetyPadding: CGFloat = 1,
        maximumNodeHeight: CGFloat = 320
    ) -> CGFloat {
        guard
            let layoutManager = textView.layoutManager,
            let textContainer = textView.textContainer
        else {
            return max(1, textView.frame.height)
        }

        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.ensureLayout(forGlyphRange: glyphRange)
        let defaultLineHeight = layoutManager.defaultLineHeight(
            for: textView.font ?? NodeTextStyle.font
        )
        var lineHeights: [CGFloat] = []
        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { _, usedRect, _, _, _ in
            lineHeights.append(max(usedRect.height, defaultLineHeight))
        }

        var contentHeight = lineHeights.reduce(0, +)
        if layoutManager.extraLineFragmentTextContainer != nil {
            contentHeight += max(lineHeights.last ?? 0, defaultLineHeight)
        }

        contentHeight = max(contentHeight, defaultLineHeight)
        let nodeHeight =
            contentHeight
            + (textView.textContainerInset.height * 2)
            + (outerVerticalPadding * 2)
            + verticalSafetyPadding
        return min(ceil(nodeHeight), maximumNodeHeight)
    }
}

/// NSTextView subclass that commits with Enter, cancels with Escape, and inserts newline with Option+Enter.
final class NodeTextEditorTextView: NSTextView {
    private static let enterKeyCode: UInt16 = 36
    private static let escapeKeyCode: UInt16 = 53

    var onCommit: (() -> Void)?
    var onCancel: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == Self.escapeKeyCode {
            // During IME composition, Escape must cancel marked text in NSTextView.
            guard !hasMarkedText() else {
                super.keyDown(with: event)
                return
            }
            onCancel?()
            return
        }

        guard event.keyCode == Self.enterKeyCode else {
            super.keyDown(with: event)
            return
        }
        // During IME composition, Enter must confirm marked text in NSTextView.
        guard !hasMarkedText() else {
            super.keyDown(with: event)
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.option), flags.isDisjoint(with: [.command, .control]) {
            insertNewline(nil)
            return
        }

        let disallowed: NSEvent.ModifierFlags = [.control, .option, .shift, .function]
        if flags.isDisjoint(with: disallowed) {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }
}
