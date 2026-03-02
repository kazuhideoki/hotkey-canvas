// Background: Diagram movement should react directly to command-arrow input without hidden direction conversion.
// Responsibility: Capture command-arrow events for diagram nodes and forward them as move commands.
import AppKit
import Application
import Domain

extension CanvasView {
    static let leftArrowKeyCode: UInt16 = 123
    static let rightArrowKeyCode: UInt16 = 124
    static let downArrowKeyCode: UInt16 = 125
    static let upArrowKeyCode: UInt16 = 126

    func handleCompositeMoveHotkey(_ event: NSEvent) -> Bool {
        guard let direction = commandOnlyArrowDirection(from: event) else {
            return false
        }
        guard Self.shouldEnableCompositeMove(direction: direction, context: keymapExecutionContext()) else {
            return false
        }

        Task {
            await viewModel.apply(commands: [.moveNode(direction)])
        }
        return true
    }

    static func shouldEnableCompositeMove(
        direction: CanvasNodeMoveDirection,
        context: KeymapExecutionContext
    ) -> Bool {
        let action = KeymapContextAction.apply(commands: [.moveNode(direction)])
        return isActionEnabled(action, context: context)
    }

    func commandOnlyArrowDirection(from event: NSEvent) -> CanvasNodeMoveDirection? {
        guard event.type == .keyDown else {
            return nil
        }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let hasCommand = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let hasOption = flags.contains(.option)
        let hasControl = flags.contains(.control)

        // Function is ignored because arrow-key shortcuts may be emitted with fn on some keyboards.
        guard hasCommand, !hasShift, !hasOption, !hasControl else {
            return nil
        }

        switch event.keyCode {
        case Self.upArrowKeyCode:
            return .up
        case Self.downArrowKeyCode:
            return .down
        case Self.leftArrowKeyCode:
            return .left
        case Self.rightArrowKeyCode:
            return .right
        default:
            return nil
        }
    }

}
