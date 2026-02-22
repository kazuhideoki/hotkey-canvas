// Background: Hotkey event handling and command-palette listing must share one shortcut source.
// Responsibility: Provide the canonical static shortcut catalog and gesture-to-action resolution.
/// Domain service that owns shortcut definitions and lookup logic.
public enum CanvasShortcutCatalogService {
    /// Resolves shortcut action for a gesture.
    /// - Parameter gesture: Canonical gesture from input adapter.
    /// - Returns: Matched action when registered.
    public static func resolveAction(for gesture: CanvasShortcutGesture) -> CanvasShortcutAction? {
        definitionsByGesture[gesture]
    }

    /// Returns command-palette visible shortcuts.
    /// - Returns: Shortcut entries visible to command palette UI.
    public static func commandPaletteDefinitions() -> [CanvasShortcutDefinition] {
        defaultDefinitionsStorage.filter(\.isVisibleInCommandPalette)
    }
}

extension CanvasShortcutCatalogService {
    private static let defaultDefinitionsStorage: [CanvasShortcutDefinition] = makeDefaultDefinitions()

    private static let definitionsByGesture: [CanvasShortcutGesture: CanvasShortcutAction] = {
        Dictionary(uniqueKeysWithValues: defaultDefinitionsStorage.map { ($0.gesture, $0.action) })
    }()

    private static func makeDefaultDefinitions() -> [CanvasShortcutDefinition] {
        commandPaletteTriggerDefinitions()
            + nodeEditingDefinitions()
            + navigationDefinitions()
            + zoomDefinitions()
            + historyDefinitions()
    }

    private static func commandPaletteTriggerDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "openCommandPalette.commandK"),
                name: "Open Command Palette",
                gesture: CanvasShortcutGesture(key: .character("k"), modifiers: [.command]),
                action: .openCommandPalette,
                shortcutLabel: "Command + K",
                searchTokens: ["palette", "command"],
                isVisibleInCommandPalette: false
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "openCommandPalette.commandShiftP"),
                name: "Open Command Palette",
                gesture: CanvasShortcutGesture(key: .character("p"), modifiers: [.command, .shift]),
                action: .openCommandPalette,
                shortcutLabel: "Command + Shift + P",
                searchTokens: ["palette", "command"],
                isVisibleInCommandPalette: false
            ),
        ]
    }

    private static func nodeEditingDefinitions() -> [CanvasShortcutDefinition] {
        baseNodeEditingDefinitions() + clipboardNodeEditingDefinitions()
    }

    private static func baseNodeEditingDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addChildNode"),
                name: "Add Child Node",
                gesture: CanvasShortcutGesture(key: .enter, modifiers: [.command]),
                action: .apply(commands: [.addChildNode]),
                shortcutLabel: "Command + Enter"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addNode"),
                name: "Add Node",
                gesture: CanvasShortcutGesture(key: .enter, modifiers: [.shift]),
                action: .apply(commands: [.addNode]),
                shortcutLabel: "Shift + Enter"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addSiblingNodeAbove"),
                name: "Add Sibling Node Above",
                gesture: CanvasShortcutGesture(key: .enter, modifiers: [.option]),
                action: .apply(commands: [.addSiblingNode(position: .above)]),
                shortcutLabel: "Option + Enter"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addSiblingNodeBelow"),
                name: "Add Sibling Node Below",
                gesture: CanvasShortcutGesture(key: .enter, modifiers: []),
                action: .apply(commands: [.addSiblingNode(position: .below)]),
                shortcutLabel: "Enter"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "deleteFocusedNode"),
                name: "Delete Focused Node",
                gesture: CanvasShortcutGesture(key: .deleteBackward, modifiers: []),
                action: .apply(commands: [.deleteFocusedNode]),
                shortcutLabel: "Delete"
            ),
        ]
    }

    private static func clipboardNodeEditingDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "copyFocusedSubtree"),
                name: "Copy Focused Subtree",
                gesture: CanvasShortcutGesture(key: .character("c"), modifiers: [.command]),
                action: .apply(commands: [.copyFocusedSubtree]),
                shortcutLabel: "Command + C",
                searchTokens: ["copy", "subtree"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "cutFocusedSubtree"),
                name: "Cut Focused Subtree",
                gesture: CanvasShortcutGesture(key: .character("x"), modifiers: [.command]),
                action: .apply(commands: [.cutFocusedSubtree]),
                shortcutLabel: "Command + X",
                searchTokens: ["cut", "subtree"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "pasteSubtreeAsChild"),
                name: "Paste Subtree as Child",
                gesture: CanvasShortcutGesture(key: .character("v"), modifiers: [.command]),
                action: .apply(commands: [.pasteSubtreeAsChild]),
                shortcutLabel: "Command + V",
                searchTokens: ["paste", "subtree", "child"]
            ),
        ]
    }

    private static func navigationDefinitions() -> [CanvasShortcutDefinition] {
        focusNavigationDefinitions()
            + nodeNavigationDefinitions()
            + canvasNavigationDefinitions()
    }

    private static func focusNavigationDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "moveFocusDown"),
                name: "Move Focus Down",
                gesture: CanvasShortcutGesture(key: .arrowDown, modifiers: []),
                action: .apply(commands: [.moveFocus(.down)]),
                shortcutLabel: "Down Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "moveFocusLeft"),
                name: "Move Focus Left",
                gesture: CanvasShortcutGesture(key: .arrowLeft, modifiers: []),
                action: .apply(commands: [.moveFocus(.left)]),
                shortcutLabel: "Left Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "moveFocusRight"),
                name: "Move Focus Right",
                gesture: CanvasShortcutGesture(key: .arrowRight, modifiers: []),
                action: .apply(commands: [.moveFocus(.right)]),
                shortcutLabel: "Right Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "moveFocusUp"),
                name: "Move Focus Up",
                gesture: CanvasShortcutGesture(key: .arrowUp, modifiers: []),
                action: .apply(commands: [.moveFocus(.up)]),
                shortcutLabel: "Up Arrow"
            ),
        ]
    }

    private static func nodeNavigationDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "moveNodeDown"),
                name: "Move Node Down",
                gesture: CanvasShortcutGesture(key: .arrowDown, modifiers: [.command]),
                action: .apply(commands: [.moveNode(.down)]),
                shortcutLabel: "Command + Down Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "moveNodeLeft"),
                name: "Move Node Left",
                gesture: CanvasShortcutGesture(key: .arrowLeft, modifiers: [.command]),
                action: .apply(commands: [.moveNode(.left)]),
                shortcutLabel: "Command + Left Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "moveNodeRight"),
                name: "Move Node Right",
                gesture: CanvasShortcutGesture(key: .arrowRight, modifiers: [.command]),
                action: .apply(commands: [.moveNode(.right)]),
                shortcutLabel: "Command + Right Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "moveNodeUp"),
                name: "Move Node Up",
                gesture: CanvasShortcutGesture(key: .arrowUp, modifiers: [.command]),
                action: .apply(commands: [.moveNode(.up)]),
                shortcutLabel: "Command + Up Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "nudgeNodeDown"),
                name: "Nudge Node Down",
                gesture: CanvasShortcutGesture(key: .arrowDown, modifiers: [.command, .shift]),
                action: .apply(commands: [.nudgeNode(.down)]),
                shortcutLabel: "Command + Shift + Down Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "nudgeNodeLeft"),
                name: "Nudge Node Left",
                gesture: CanvasShortcutGesture(key: .arrowLeft, modifiers: [.command, .shift]),
                action: .apply(commands: [.nudgeNode(.left)]),
                shortcutLabel: "Command + Shift + Left Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "nudgeNodeRight"),
                name: "Nudge Node Right",
                gesture: CanvasShortcutGesture(key: .arrowRight, modifiers: [.command, .shift]),
                action: .apply(commands: [.nudgeNode(.right)]),
                shortcutLabel: "Command + Shift + Right Arrow"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "nudgeNodeUp"),
                name: "Nudge Node Up",
                gesture: CanvasShortcutGesture(key: .arrowUp, modifiers: [.command, .shift]),
                action: .apply(commands: [.nudgeNode(.up)]),
                shortcutLabel: "Command + Shift + Up Arrow"
            ),
        ]
    }

    private static func canvasNavigationDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "centerFocusedNode"),
                name: "Center Focused Node",
                gesture: CanvasShortcutGesture(key: .character("l"), modifiers: [.control]),
                action: .apply(commands: [.centerFocusedNode]),
                shortcutLabel: "Control + L"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "toggleFoldFocusedSubtree"),
                name: "Toggle Fold Focused Subtree",
                gesture: CanvasShortcutGesture(key: .character("."), modifiers: [.option]),
                action: .apply(commands: [.toggleFoldFocusedSubtree]),
                shortcutLabel: "Option + .",
                searchTokens: ["fold", "collapse", "expand", "subtree"]
            ),
        ]
    }

    private static func historyDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "undo"),
                name: "Undo",
                gesture: CanvasShortcutGesture(key: .character("z"), modifiers: [.command]),
                action: .undo,
                shortcutLabel: "Command + Z"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "redo.commandShiftZ"),
                name: "Redo",
                gesture: CanvasShortcutGesture(key: .character("z"), modifiers: [.command, .shift]),
                action: .redo,
                shortcutLabel: "Command + Shift + Z"
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "redo.commandY"),
                name: "Redo",
                gesture: CanvasShortcutGesture(key: .character("y"), modifiers: [.command]),
                action: .redo,
                shortcutLabel: "Command + Y"
            ),
        ]
    }

    private static func zoomDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomIn.commandPlus"),
                name: "Zoom In",
                gesture: CanvasShortcutGesture(key: .character("+"), modifiers: [.command]),
                action: .zoomIn,
                shortcutLabel: "Command + +",
                searchTokens: ["zoom", "in", "scale"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomIn.commandShiftSemicolon"),
                name: "Zoom In",
                gesture: CanvasShortcutGesture(key: .character(";"), modifiers: [.command, .shift]),
                action: .zoomIn,
                shortcutLabel: "Command + +",
                searchTokens: ["zoom", "in", "scale"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomIn.commandShiftEquals"),
                name: "Zoom In",
                gesture: CanvasShortcutGesture(key: .character("="), modifiers: [.command, .shift]),
                action: .zoomIn,
                shortcutLabel: "Command + +",
                searchTokens: ["zoom", "in", "scale"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomIn.commandEquals"),
                name: "Zoom In",
                gesture: CanvasShortcutGesture(key: .character("="), modifiers: [.command]),
                action: .zoomIn,
                shortcutLabel: "Command + =",
                searchTokens: ["zoom", "in", "scale"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomOut.commandMinus"),
                name: "Zoom Out",
                gesture: CanvasShortcutGesture(key: .character("-"), modifiers: [.command]),
                action: .zoomOut,
                shortcutLabel: "Command + -",
                searchTokens: ["zoom", "out", "scale"]
            ),
        ]
    }
}
