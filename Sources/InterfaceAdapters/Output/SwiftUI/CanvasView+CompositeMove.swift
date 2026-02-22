// Background: Diagram movement should support diagonal stepping from sequential command-arrow inputs.
// Responsibility: Convert consecutive command-arrow key presses into cardinal/diagonal move commands.
import AppKit
import Domain

extension CanvasView {
    static let leftArrowKeyCode: UInt16 = 123
    static let rightArrowKeyCode: UInt16 = 124
    static let downArrowKeyCode: UInt16 = 125
    static let upArrowKeyCode: UInt16 = 126

    func handleCompositeMoveHotkey(_ event: NSEvent) -> Bool {
        guard let direction = commandOnlyArrowDirection(from: event) else {
            previousCompositeMoveInputDirection = nil
            return false
        }

        let outputDirection = compositeDirection(
            previousInput: previousCompositeMoveInputDirection,
            currentInput: direction
        )
        previousCompositeMoveInputDirection = direction

        Task {
            await viewModel.apply(commands: [.moveNode(outputDirection)])
        }
        return true
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

    func compositeDirection(
        previousInput: CanvasNodeMoveDirection?,
        currentInput: CanvasNodeMoveDirection
    ) -> CanvasNodeMoveDirection {
        guard let previousInput else {
            return currentInput
        }
        switch (previousInput, currentInput) {
        case (.up, .left), (.left, .up):
            return .upLeft
        case (.up, .right), (.right, .up):
            return .upRight
        case (.down, .left), (.left, .down):
            return .downLeft
        case (.down, .right), (.right, .down):
            return .downRight
        default:
            return currentInput
        }
    }
}
