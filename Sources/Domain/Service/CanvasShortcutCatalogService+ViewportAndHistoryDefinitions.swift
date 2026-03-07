// Background: Viewport zoom and history actions are shared across all contexts.
// Responsibility: Provide shortcut definitions and rendering utilities for global-style commands.
extension CanvasShortcutCatalogService {
    static func historyDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "undo"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "History", verb: "Undo"),
                gesture: CanvasShortcutGesture(key: .character("z"), modifiers: [.command]),
                action: .undo,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("z"), modifiers: [.command])
                )
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "redo.commandShiftZ"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "History", verb: "Redo"),
                gesture: CanvasShortcutGesture(key: .character("z"), modifiers: [.command, .shift]),
                action: .redo,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("z"), modifiers: [.command, .shift])
                )
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "redo.commandY"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "History", verb: "Redo"),
                gesture: CanvasShortcutGesture(key: .character("y"), modifiers: [.command]),
                action: .redo,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("y"), modifiers: [.command])
                )
            ),
        ]
    }

    static func zoomDefinitions() -> [CanvasShortcutDefinition] {
        [
            zoomDefinition(
                id: "zoomIn.commandPlus",
                key: .character("+"),
                modifiers: [.command],
                action: .zoomIn,
                shortcutLabel: shortcutLabel(modifiers: [.command], keyLabel: "+")
            ),
            zoomDefinition(
                id: "zoomIn.commandShiftSemicolon",
                key: .character(";"),
                modifiers: [.command, .shift],
                action: .zoomIn,
                shortcutLabel: shortcutLabel(modifiers: [.command], keyLabel: "+")
            ),
            zoomDefinition(
                id: "zoomIn.commandShiftEquals",
                key: .character("="),
                modifiers: [.command, .shift],
                action: .zoomIn,
                shortcutLabel: shortcutLabel(modifiers: [.command], keyLabel: "+")
            ),
            zoomDefinition(
                id: "zoomIn.commandEquals",
                key: .character("="),
                modifiers: [.command],
                action: .zoomIn,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("="), modifiers: [.command])
                )
            ),
            zoomDefinition(
                id: "zoomOut.commandMinus",
                key: .character("-"),
                modifiers: [.command],
                action: .zoomOut,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("-"), modifiers: [.command])
                )
            ),
        ]
    }

    static func shortcutLabel(for gesture: CanvasShortcutGesture) -> String {
        shortcutLabel(modifiers: gesture.modifiers, keyLabel: keyLabel(for: gesture.key))
    }

    static func shortcutLabel(modifiers: CanvasShortcutModifiers, keyLabel: String) -> String {
        modifierSymbols(for: modifiers).joined() + keyLabel
    }

    static func modifierSymbols(for modifiers: CanvasShortcutModifiers) -> [String] {
        [
            modifiers.contains(.command) ? "⌘" : nil,
            modifiers.contains(.shift) ? "⇧" : nil,
            modifiers.contains(.control) ? "⌃" : nil,
            modifiers.contains(.option) ? "⌥" : nil,
            modifiers.contains(.function) ? "fn" : nil,
        ].compactMap { $0 }
    }

    static func keyLabel(for key: CanvasShortcutKey) -> String {
        switch key {
        case .tab:
            "⇥"
        case .enter:
            "↩"
        case .deleteBackward:
            "⌫"
        case .deleteForward:
            "⌦"
        case .arrowUp:
            "↑"
        case .arrowDown:
            "↓"
        case .arrowLeft:
            "←"
        case .arrowRight:
            "→"
        case .character(let character):
            character.uppercased()
        }
    }

    private static func zoomDefinition(
        id: String,
        key: CanvasShortcutKey,
        modifiers: CanvasShortcutModifiers,
        action: CanvasShortcutAction,
        shortcutLabel: String
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: id),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Viewport", verb: action == .zoomIn ? "Zoom In" : "Zoom Out"),
            gesture: CanvasShortcutGesture(key: key, modifiers: modifiers),
            action: action,
            shortcutLabel: shortcutLabel,
            searchTokens: action == .zoomIn ? ["zoom", "in", "scale"] : ["zoom", "out", "scale"]
        )
    }
}
