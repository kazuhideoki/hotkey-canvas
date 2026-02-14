// Background: Node inline editing needs AppKit key handling not exposed by SwiftUI text components.
// Responsibility: Provide an NSTextView bridge with Enter commit, Escape cancel, and Option+Enter newline behavior.
import AppKit
import SwiftUI

/// Inline editor used for canvas node text editing.
struct NodeTextEditor: NSViewRepresentable {
    @Binding var text: String
    let selectAllOnFirstFocus: Bool
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
        nsView.typingAttributes[.foregroundColor] = NSColor.white
        focusEditorIfNeeded(nsView, coordinator: context.coordinator)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, selectAllOnFirstFocus: selectAllOnFirstFocus)
    }
}

extension NodeTextEditor {
    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>
        let selectAllOnFirstFocus: Bool
        var hasFocusedEditor: Bool = false

        init(text: Binding<String>, selectAllOnFirstFocus: Bool) {
            self.text = text
            self.selectAllOnFirstFocus = selectAllOnFirstFocus
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }
            text.wrappedValue = textView.string
        }
    }

    private func configureTextViewAppearance(_ textView: NodeTextEditorTextView) {
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.font = .systemFont(ofSize: 14, weight: .medium)
        textView.textColor = .white
        textView.insertionPointColor = .white
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
        textView.typingAttributes = [.foregroundColor: NSColor.white]
    }

    private func focusEditorIfNeeded(
        _ textView: NodeTextEditorTextView,
        coordinator: Coordinator
    ) {
        DispatchQueue.main.async {
            guard let window = textView.window, window.firstResponder !== textView else {
                return
            }
            window.makeFirstResponder(textView)
            if coordinator.selectAllOnFirstFocus, !coordinator.hasFocusedEditor {
                textView.selectAll(nil)
            }
            coordinator.hasFocusedEditor = true
        }
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

        let disallowed: NSEvent.ModifierFlags = [.command, .control, .shift, .function]
        if flags.isDisjoint(with: disallowed) {
            onCommit?()
            return
        }
        super.keyDown(with: event)
    }
}
