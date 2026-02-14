import AppKit
import Domain

public enum CanvasHistoryAction: Equatable, Sendable {
    case undo
    case redo
}

public struct CanvasHotkeyTranslator {
    public init() {}

    public func historyAction(_ event: NSEvent) -> CanvasHistoryAction? {
        guard event.type == .keyDown else {
            return nil
        }
        if isUndo(event) {
            return .undo
        }
        if isRedo(event) {
            return .redo
        }
        return nil
    }

    public func translate(_ event: NSEvent) -> [CanvasCommand] {
        guard event.type == .keyDown else {
            return []
        }
        if isCommandEnter(event) {
            return [.addChildNode]
        }
        if isEnterWithoutDisallowedModifiers(event) {
            return [.addSiblingNode]
        }
        if isShiftEnter(event) {
            return [.addNode]
        }
        if isDelete(event) {
            return [.deleteFocusedNode]
        }
        guard let direction = focusDirectionIfArrow(event) else {
            return []
        }
        return [.moveFocus(direction)]
    }
}

extension CanvasHotkeyTranslator {
    private static let deleteKeyCode: UInt16 = 51
    private static let forwardDeleteKeyCode: UInt16 = 117
    private static let leftArrowKeyCode: UInt16 = 123
    private static let rightArrowKeyCode: UInt16 = 124
    private static let downArrowKeyCode: UInt16 = 125
    private static let upArrowKeyCode: UInt16 = 126
    private static let zKeyCode: UInt16 = 6
    private static let yKeyCode: UInt16 = 16

    private func isShiftEnter(_ event: NSEvent) -> Bool {
        guard event.keyCode == 36 else {
            return false
        }

        let flags = normalizedFlags(from: event)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .function]
        return flags.contains(.shift) && flags.isDisjoint(with: disallowed)
    }

    private func isCommandEnter(_ event: NSEvent) -> Bool {
        guard event.keyCode == 36 else {
            return false
        }

        let flags = normalizedFlags(from: event)
        let disallowed: NSEvent.ModifierFlags = [.shift, .control, .option, .function]
        return flags.contains(.command) && flags.isDisjoint(with: disallowed)
    }

    private func isUndo(_ event: NSEvent) -> Bool {
        guard event.keyCode == Self.zKeyCode else {
            return false
        }

        let flags = normalizedFlags(from: event)
        let disallowed: NSEvent.ModifierFlags = [.shift, .control, .option, .function]
        return flags.contains(.command) && flags.isDisjoint(with: disallowed)
    }

    private func isRedo(_ event: NSEvent) -> Bool {
        let flags = normalizedFlags(from: event)
        let disallowed: NSEvent.ModifierFlags = [.control, .option, .function]
        if event.keyCode == Self.zKeyCode {
            return flags.contains([.command, .shift]) && flags.isDisjoint(with: disallowed)
        }
        if event.keyCode == Self.yKeyCode {
            let yDisallowed: NSEvent.ModifierFlags = [.shift, .control, .option, .function]
            return flags.contains(.command) && flags.isDisjoint(with: yDisallowed)
        }
        return false
    }

    private func isEnterWithoutDisallowedModifiers(_ event: NSEvent) -> Bool {
        guard event.keyCode == 36 else {
            return false
        }

        let flags = normalizedFlags(from: event)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .shift, .function]
        return flags.isDisjoint(with: disallowed)
    }

    private func isDelete(_ event: NSEvent) -> Bool {
        guard event.keyCode == Self.deleteKeyCode || event.keyCode == Self.forwardDeleteKeyCode else {
            return false
        }

        let flags = normalizedFlags(from: event)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        return flags.isDisjoint(with: disallowed)
    }

    private func focusDirectionIfArrow(_ event: NSEvent) -> CanvasFocusDirection? {
        let flags = normalizedFlags(from: event)
        // NOTE: Some environments attach `.function` to arrow-key events.
        // We only block modifiers that should explicitly change shortcut meaning.
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
        guard flags.isDisjoint(with: disallowed) else {
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

    private func normalizedFlags(from event: NSEvent) -> NSEvent.ModifierFlags {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    }
}
