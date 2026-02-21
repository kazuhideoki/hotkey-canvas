// Background: Input events must resolve against one canonical shortcut catalog shared with command palette.
// Responsibility: Normalize AppKit key events and map them to domain shortcut actions.
import AppKit
import Domain

public enum CanvasHistoryAction: Equatable, Sendable {
    case undo
    case redo
}

public enum CanvasZoomAction: Equatable, Sendable {
    case zoomIn
    case zoomOut
}

public struct CanvasHotkeyTranslator {
    public init() {}

    public func historyAction(_ event: NSEvent) -> CanvasHistoryAction? {
        switch action(for: event) {
        case .undo:
            return .undo
        case .redo:
            return .redo
        case .apply, .zoomIn, .zoomOut, .openCommandPalette, .none:
            return nil
        }
    }

    public func zoomAction(_ event: NSEvent) -> CanvasZoomAction? {
        switch action(for: event) {
        case .zoomIn:
            return .zoomIn
        case .zoomOut:
            return .zoomOut
        case .apply, .undo, .redo, .openCommandPalette, .none:
            return nil
        }
    }

    // Command-palette trigger is treated as input-adapter concern:
    // it decides UI mode switching only, not domain/application behavior.
    public func shouldOpenCommandPalette(_ event: NSEvent) -> Bool {
        action(for: event) == .openCommandPalette
    }

    /// Returns true when Shift+Enter should open mode selection instead of direct add-node apply.
    public func shouldPresentAddNodeModeSelection(_ event: NSEvent) -> Bool {
        action(for: event) == .apply(commands: [.addNode])
    }

    public func translate(_ event: NSEvent) -> [CanvasCommand] {
        switch action(for: event) {
        case .apply(let commands):
            return commands
        case .undo, .redo, .zoomIn, .zoomOut, .openCommandPalette, .none:
            return []
        }
    }
}

extension CanvasHotkeyTranslator {
    private static let enterKeyCode: UInt16 = 36
    private static let deleteKeyCode: UInt16 = 51
    private static let forwardDeleteKeyCode: UInt16 = 117
    private static let leftArrowKeyCode: UInt16 = 123
    private static let rightArrowKeyCode: UInt16 = 124
    private static let downArrowKeyCode: UInt16 = 125
    private static let upArrowKeyCode: UInt16 = 126
    private static let lKeyCode: UInt16 = 37
    private static let equalsKeyCode: UInt16 = 24
    private static let minusKeyCode: UInt16 = 27
    private static let semicolonKeyCode: UInt16 = 41
    private static let keypadPlusKeyCode: UInt16 = 69

    private func action(for event: NSEvent) -> CanvasShortcutAction? {
        guard event.type == .keyDown else {
            return nil
        }
        if let zoomAction = zoomActionByKeyCode(from: event) {
            return zoomAction
        }
        guard let gesture = gesture(from: event) else {
            return nil
        }
        if let action = CanvasShortcutCatalogService.resolveAction(for: gesture) {
            return action
        }

        guard gesture.modifiers.contains(.function), canIgnoreFunctionModifier(for: gesture.key) else {
            return nil
        }
        var modifiersWithoutFunction = gesture.modifiers
        modifiersWithoutFunction.remove(.function)

        let normalizedGesture = CanvasShortcutGesture(
            key: gesture.key,
            modifiers: modifiersWithoutFunction
        )
        return CanvasShortcutCatalogService.resolveAction(for: normalizedGesture)
    }

    private func zoomActionByKeyCode(from event: NSEvent) -> CanvasShortcutAction? {
        let flags = normalizedFlags(from: event)
        let isCommandOnly = hasExactZoomModifiers(flags, requiresShift: false)
        let isCommandShiftOnly = hasExactZoomModifiers(flags, requiresShift: true)

        if event.keyCode == Self.minusKeyCode, isCommandOnly {
            return .zoomOut
        }
        if event.keyCode == Self.keypadPlusKeyCode, isCommandOnly {
            return .zoomIn
        }
        if event.keyCode == Self.equalsKeyCode, isCommandOnly || isCommandShiftOnly {
            return .zoomIn
        }
        if event.keyCode == Self.semicolonKeyCode, isCommandShiftOnly {
            return .zoomIn
        }
        return nil
    }

    private func hasExactZoomModifiers(_ flags: NSEvent.ModifierFlags, requiresShift: Bool) -> Bool {
        let hasCommand = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let hasOption = flags.contains(.option)
        let hasControl = flags.contains(.control)
        let hasFunction = flags.contains(.function)

        guard hasCommand else {
            return false
        }
        guard hasShift == requiresShift else {
            return false
        }
        return !hasOption && !hasControl && !hasFunction
    }

    private func gesture(from event: NSEvent) -> CanvasShortcutGesture? {
        let modifiers = shortcutModifiers(from: event)
        guard let key = shortcutKey(from: event) else {
            return nil
        }
        return CanvasShortcutGesture(key: key, modifiers: modifiers)
    }

    private func shortcutKey(from event: NSEvent) -> CanvasShortcutKey? {
        switch event.keyCode {
        case Self.enterKeyCode:
            return .enter
        case Self.deleteKeyCode:
            return .deleteBackward
        case Self.forwardDeleteKeyCode:
            return .deleteBackward
        case Self.lKeyCode:
            return .character("l")
        case Self.upArrowKeyCode:
            return .arrowUp
        case Self.downArrowKeyCode:
            return .arrowDown
        case Self.leftArrowKeyCode:
            return .arrowLeft
        case Self.rightArrowKeyCode:
            return .arrowRight
        default:
            guard let character = normalizedShortcutCharacter(from: event) else {
                return nil
            }
            return .character(character)
        }
    }

    private func canIgnoreFunctionModifier(for key: CanvasShortcutKey) -> Bool {
        switch key {
        case .arrowUp, .arrowDown, .arrowLeft, .arrowRight, .deleteBackward, .deleteForward:
            return true
        case .enter, .character:
            return false
        }
    }

    private func shortcutModifiers(from event: NSEvent) -> CanvasShortcutModifiers {
        let flags = normalizedFlags(from: event)
        var modifiers = CanvasShortcutModifiers()

        if flags.contains(.command) {
            modifiers.insert(.command)
        }
        if flags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if flags.contains(.option) {
            modifiers.insert(.option)
        }
        if flags.contains(.control) {
            modifiers.insert(.control)
        }
        if flags.contains(.function) {
            modifiers.insert(.function)
        }

        return modifiers
    }

    private func normalizedFlags(from event: NSEvent) -> NSEvent.ModifierFlags {
        event.modifierFlags.intersection(.deviceIndependentFlagsMask)
    }

    private func normalizedShortcutCharacter(from event: NSEvent) -> String? {
        if let shiftedCharacter = normalizedSymbolCharacter(from: event) {
            return shiftedCharacter
        }
        guard let charactersIgnoringModifiers = event.charactersIgnoringModifiers else {
            return nil
        }
        let normalized = charactersIgnoringModifiers.lowercased()
        guard normalized.count == 1 else {
            return nil
        }
        return normalized
    }

    private func normalizedSymbolCharacter(from event: NSEvent) -> String? {
        guard let characters = event.characters?.lowercased(), characters.count == 1 else {
            return nil
        }
        switch characters {
        case "+", "-":
            return characters
        default:
            return nil
        }
    }
}
