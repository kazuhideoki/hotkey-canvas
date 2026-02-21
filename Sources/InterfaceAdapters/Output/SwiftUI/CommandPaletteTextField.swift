// Background: Command palette query editing should follow native macOS text system behavior.
// Responsibility: Bridge an AppKit text field into SwiftUI and expose palette-specific key hooks.
import AppKit
import SwiftUI

/// SwiftUI wrapper for a command-palette query field with native text editing behavior.
struct CommandPaletteTextField: NSViewRepresentable {
    @Binding var text: String
    let onSubmit: () -> Void
    let onCancel: () -> Void
    let onMoveSelectionUp: () -> Void
    let onMoveSelectionDown: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            onSubmit: onSubmit,
            onCancel: onCancel,
            onMoveSelectionUp: onMoveSelectionUp,
            onMoveSelectionDown: onMoveSelectionDown
        )
    }

    func makeNSView(context: Context) -> CommandPaletteNSTextField {
        let textField = CommandPaletteNSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.isBezeled = false
        textField.isEditable = true
        textField.isSelectable = true
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textField.lineBreakMode = .byClipping
        textField.maximumNumberOfLines = 1
        textField.placeholderString = "Search commands"
        textField.stringValue = text
        return textField
    }

    func updateNSView(_ nsView: CommandPaletteNSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.updateHandlers(
            onSubmit: onSubmit,
            onCancel: onCancel,
            onMoveSelectionUp: onMoveSelectionUp,
            onMoveSelectionDown: onMoveSelectionDown
        )
    }
}

extension CommandPaletteTextField {
    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let text: Binding<String>
        private var onSubmit: () -> Void
        private var onCancel: () -> Void
        private var onMoveSelectionUp: () -> Void
        private var onMoveSelectionDown: () -> Void

        init(
            text: Binding<String>,
            onSubmit: @escaping () -> Void,
            onCancel: @escaping () -> Void,
            onMoveSelectionUp: @escaping () -> Void,
            onMoveSelectionDown: @escaping () -> Void
        ) {
            self.text = text
            self.onSubmit = onSubmit
            self.onCancel = onCancel
            self.onMoveSelectionUp = onMoveSelectionUp
            self.onMoveSelectionDown = onMoveSelectionDown
        }

        func updateHandlers(
            onSubmit: @escaping () -> Void,
            onCancel: @escaping () -> Void,
            onMoveSelectionUp: @escaping () -> Void,
            onMoveSelectionDown: @escaping () -> Void
        ) {
            self.onSubmit = onSubmit
            self.onCancel = onCancel
            self.onMoveSelectionUp = onMoveSelectionUp
            self.onMoveSelectionDown = onMoveSelectionDown
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }
            text.wrappedValue = textField.stringValue
        }

        func control(
            _ control: NSControl,
            textView: NSTextView,
            doCommandBy commandSelector: Selector
        ) -> Bool {
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                onCancel()
                return true
            case #selector(NSResponder.moveUp(_:)):
                onMoveSelectionUp()
                return true
            case #selector(NSResponder.moveDown(_:)):
                onMoveSelectionDown()
                return true
            default:
                return false
            }
        }
    }
}

/// AppKit text field that keeps native editing commands and intercepts palette-only actions.
final class CommandPaletteNSTextField: NSTextField {
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
