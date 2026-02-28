// Background: Input events must resolve against one canonical keymap route shared across UI behaviors.
// Responsibility: Normalize AppKit key events and resolve them into scoped keymap routes.
import AppKit
import Domain

/// Translates one AppKit key event into a canonical keymap route.
public struct CanvasHotkeyTranslator {
    public init() {}

    /// Resolves one route from an incoming key event.
    /// - Parameter event: AppKit key event.
    /// - Returns: Scoped keymap route, or `nil` when the event is unrelated to keymap handling.
    public func resolve(_ event: NSEvent) -> KeymapResolvedRoute? {
        guard event.type == .keyDown else {
            return nil
        }
        if let route = nodeScaleRouteByKeyCode(from: event) {
            return route
        }
        if let route = zoomRouteByKeyCode(from: event) {
            return route
        }
        guard let gesture = gesture(from: event) else {
            return nil
        }
        if let route = KeymapIntentResolver.resolveRoute(for: gesture) {
            return route
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
        return KeymapIntentResolver.resolveRoute(for: normalizedGesture)
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

    private func nodeScaleRouteByKeyCode(from event: NSEvent) -> KeymapResolvedRoute? {
        let flags = normalizedFlags(from: event)
        let isCommandOptionOnly = hasExactNodeScaleModifiers(flags, requiresShift: false)
        let isCommandOptionShiftOnly = hasExactNodeScaleModifiers(flags, requiresShift: true)

        if event.keyCode == Self.minusKeyCode, isCommandOptionOnly {
            return .primitive(intent: .transform(variant: .scaleSelectionDown))
        }
        if event.keyCode == Self.keypadPlusKeyCode, isCommandOptionOnly {
            return .primitive(intent: .transform(variant: .scaleSelectionUp))
        }
        if event.keyCode == Self.equalsKeyCode, isCommandOptionOnly || isCommandOptionShiftOnly {
            return .primitive(intent: .transform(variant: .scaleSelectionUp))
        }
        if event.keyCode == Self.semicolonKeyCode, isCommandOptionShiftOnly {
            return .primitive(intent: .transform(variant: .scaleSelectionUp))
        }
        return nil
    }

    private func zoomRouteByKeyCode(from event: NSEvent) -> KeymapResolvedRoute? {
        let flags = normalizedFlags(from: event)
        let isCommandOnly = hasExactZoomModifiers(flags, requiresShift: false)
        let isCommandShiftOnly = hasExactZoomModifiers(flags, requiresShift: true)

        if event.keyCode == Self.minusKeyCode, isCommandOnly {
            return .global(action: .zoomOut)
        }
        if event.keyCode == Self.keypadPlusKeyCode, isCommandOnly {
            return .global(action: .zoomIn)
        }
        if event.keyCode == Self.equalsKeyCode, isCommandOnly || isCommandShiftOnly {
            return .global(action: .zoomIn)
        }
        if event.keyCode == Self.semicolonKeyCode, isCommandShiftOnly {
            return .global(action: .zoomIn)
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

    private func hasExactNodeScaleModifiers(_ flags: NSEvent.ModifierFlags, requiresShift: Bool) -> Bool {
        let hasCommand = flags.contains(.command)
        let hasShift = flags.contains(.shift)
        let hasOption = flags.contains(.option)
        let hasControl = flags.contains(.control)
        let hasFunction = flags.contains(.function)

        guard hasCommand, hasOption else {
            return false
        }
        guard hasShift == requiresShift else {
            return false
        }
        return !hasControl && !hasFunction
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
