// Background: Inline canvas search needs AppKit text behavior with Enter/Shift+Enter cycling semantics.
// Responsibility: Bridge a native NSTextField for search query input and search-specific key hooks.
import AppKit
import SwiftUI

struct CanvasSearchTextField: NSViewRepresentable {
    struct Handlers {
        let onSubmitForward: () -> Void
        let onSubmitBackward: () -> Void
        let onMoveHistoryOlder: () -> Void
        let onMoveHistoryNewer: () -> Void
        let onTextEdited: () -> Void
        let onCancel: () -> Void
    }

    @Binding var text: String
    let onSubmitForward: () -> Void
    let onSubmitBackward: () -> Void
    let onMoveHistoryOlder: () -> Void
    let onMoveHistoryNewer: () -> Void
    let onTextEdited: () -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, handlers: currentHandlers())
    }

    func makeNSView(context: Context) -> CanvasSearchNSTextField {
        let textField = CanvasSearchNSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.isBezeled = false
        textField.isEditable = true
        textField.isSelectable = true
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 13, weight: .medium)
        textField.lineBreakMode = .byClipping
        textField.maximumNumberOfLines = 1
        textField.placeholderString = "Search nodes"
        textField.stringValue = text
        return textField
    }

    func updateNSView(_ nsView: CanvasSearchNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.updateHandlers(currentHandlers())
    }

    private func currentHandlers() -> Handlers {
        Handlers(
            onSubmitForward: onSubmitForward,
            onSubmitBackward: onSubmitBackward,
            onMoveHistoryOlder: onMoveHistoryOlder,
            onMoveHistoryNewer: onMoveHistoryNewer,
            onTextEdited: onTextEdited,
            onCancel: onCancel
        )
    }
}

extension CanvasSearchTextField {
    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let text: Binding<String>
        private var onSubmitForward: () -> Void
        private var onSubmitBackward: () -> Void
        private var onMoveHistoryOlder: () -> Void
        private var onMoveHistoryNewer: () -> Void
        private var onTextEdited: () -> Void
        private var onCancel: () -> Void

        init(text: Binding<String>, handlers: Handlers) {
            self.text = text
            onSubmitForward = handlers.onSubmitForward
            onSubmitBackward = handlers.onSubmitBackward
            onMoveHistoryOlder = handlers.onMoveHistoryOlder
            onMoveHistoryNewer = handlers.onMoveHistoryNewer
            onTextEdited = handlers.onTextEdited
            onCancel = handlers.onCancel
        }

        func updateHandlers(_ handlers: Handlers) {
            onSubmitForward = handlers.onSubmitForward
            onSubmitBackward = handlers.onSubmitBackward
            onMoveHistoryOlder = handlers.onMoveHistoryOlder
            onMoveHistoryNewer = handlers.onMoveHistoryNewer
            onTextEdited = handlers.onTextEdited
            onCancel = handlers.onCancel
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }
            text.wrappedValue = textField.stringValue
            onTextEdited()
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                guard textView.hasMarkedText() == false else {
                    return false
                }
                let flags =
                    NSApplication.shared.currentEvent?.modifierFlags.intersection(
                        .deviceIndependentFlagsMask
                    ) ?? []
                if flags.contains(.shift) {
                    onSubmitBackward()
                } else {
                    onSubmitForward()
                }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                onCancel()
                return true
            case #selector(NSResponder.moveUp(_:)):
                guard textView.hasMarkedText() == false else {
                    return false
                }
                onMoveHistoryOlder()
                return true
            case #selector(NSResponder.moveDown(_:)):
                guard textView.hasMarkedText() == false else {
                    return false
                }
                onMoveHistoryNewer()
                return true
            default:
                return false
            }
        }
    }
}

final class CanvasSearchNSTextField: NSTextField {
    private var didRequestInitialFocus = false

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard !didRequestInitialFocus else {
            return
        }
        didRequestInitialFocus = true
        DispatchQueue.main.async { [weak self] in
            guard let self, let window = self.window else {
                return
            }
            window.makeFirstResponder(self)
        }
    }
}
