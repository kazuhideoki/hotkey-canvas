// Background: Shift+Enter opens a mode-selection popup that must resolve key presses without relying on system dialogs.
// Responsibility: Translate popup key-down events into add-node mode-selection actions.
import AppKit

/// Popup action triggered by keyboard input while add-node mode selection is visible.
enum AddNodeModeSelectionPopupAction: Equatable {
    case selectTree
    case selectDiagram
    case moveSelection(delta: Int)
    case confirmSelection
    case dismiss
}

/// Resolves NSEvent key-down events into popup actions for add-node mode selection.
struct AddNodeModeSelectionHotkeyResolver {
    private static let escapeKeyCode: UInt16 = 53
    private static let enterKeyCode: UInt16 = 36
    private static let upArrowKeyCode: UInt16 = 126
    private static let downArrowKeyCode: UInt16 = 125

    /// Resolves one popup action for a key-down event.
    /// - Parameter event: Incoming AppKit event.
    /// - Returns: Resolved popup action, or `nil` when the key should be ignored.
    func action(for event: NSEvent) -> AddNodeModeSelectionPopupAction? {
        guard event.type == .keyDown else {
            return nil
        }
        switch event.keyCode {
        case Self.escapeKeyCode:
            return .dismiss
        case Self.enterKeyCode:
            return .confirmSelection
        case Self.upArrowKeyCode:
            return .moveSelection(delta: -1)
        case Self.downArrowKeyCode:
            return .moveSelection(delta: 1)
        default:
            break
        }

        guard
            let charactersIgnoringModifiers = event.charactersIgnoringModifiers?.lowercased(),
            charactersIgnoringModifiers.count == 1
        else {
            return nil
        }
        switch charactersIgnoringModifiers {
        case "t":
            return .selectTree
        case "d":
            return .selectDiagram
        default:
            return nil
        }
    }
}
