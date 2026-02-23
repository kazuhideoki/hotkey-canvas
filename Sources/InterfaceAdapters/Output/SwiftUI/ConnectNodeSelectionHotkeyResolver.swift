// Background: Connect-node mode requires modal keyboard handling without relying on platform dialogs.
// Responsibility: Resolve key-down events into connect-mode selection actions.
import AppKit
import Domain

/// Action emitted while connect-node selection mode is active.
enum ConnectNodeSelectionAction: Equatable {
    case moveSelection(CanvasFocusDirection)
    case confirmSelection
    case dismiss
}

/// Resolves one key event into a connect-node selection action.
struct ConnectNodeSelectionHotkeyResolver {
    private static let escapeKeyCode: UInt16 = 53
    private static let enterKeyCode: UInt16 = 36
    private static let leftArrowKeyCode: UInt16 = 123
    private static let rightArrowKeyCode: UInt16 = 124
    private static let downArrowKeyCode: UInt16 = 125
    private static let upArrowKeyCode: UInt16 = 126

    /// Resolves one action from the incoming event.
    /// - Parameter event: Incoming AppKit key event.
    /// - Returns: Selection action or `nil` for unrelated keys.
    func action(for event: NSEvent) -> ConnectNodeSelectionAction? {
        guard event.type == .keyDown else {
            return nil
        }
        switch event.keyCode {
        case Self.escapeKeyCode:
            return .dismiss
        case Self.enterKeyCode:
            return .confirmSelection
        case Self.leftArrowKeyCode:
            return .moveSelection(.left)
        case Self.rightArrowKeyCode:
            return .moveSelection(.right)
        case Self.downArrowKeyCode:
            return .moveSelection(.down)
        case Self.upArrowKeyCode:
            return .moveSelection(.up)
        default:
            return nil
        }
    }
}
