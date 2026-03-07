// Background: Canvas-wide shortcuts cover viewport, connect mode, and label formatting helpers.
// Responsibility: Build canvas-level shortcut definitions and shortcut label helpers.
extension CanvasShortcutCatalogService {
    static func canvasNavigationDefinitions() -> [CanvasShortcutDefinition] {
        [
            beginConnectNodeSelectionDefinition(),
            centerFocusedNodeDefinition(),
            toggleFoldFocusedSubtreeDefinition(),
            toggleFocusedAreaEdgeShapeStyleDefinition(),
        ]
    }

    private static func beginConnectNodeSelectionDefinition() -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "beginConnectNodeSelection"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Edge",
                verb: "Connect Focused Node"
            ),
            gesture: CanvasShortcutGesture(key: .character("l"), modifiers: [.command]),
            action: .beginConnectNodeSelection,
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: .character("l"), modifiers: [.command])
            ),
            searchTokens: ["connect", "edge", "line", "diagram"],
            commandPaletteVisibility: .requiresFocusedNodeAndMode([.diagram]),
            executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNodeAndMode([.diagram]))
        )
    }

    private static func centerFocusedNodeDefinition() -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "centerFocusedNode"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Viewport",
                verb: "Center Focused Node"
            ),
            gesture: CanvasShortcutGesture(key: .character("l"), modifiers: [.control]),
            action: .apply(commands: [.centerFocusedNode]),
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: .character("l"), modifiers: [.control])
            ),
            commandPaletteVisibility: .requiresFocusedNode,
            executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode)
        )
    }

    private static func toggleFoldFocusedSubtreeDefinition() -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "toggleFoldFocusedSubtree"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Subtree",
                verb: "Toggle Fold"
            ),
            gesture: CanvasShortcutGesture(key: .character("."), modifiers: [.option]),
            action: .apply(commands: [.toggleFoldFocusedSubtree]),
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: .character("."), modifiers: [.option])
            ),
            searchTokens: [
                "fold",
                "toggle",
                "collapse",
                "expand",
                "enable",
                "disable",
                "focused",
                "subtree",
            ],
            commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree]),
            executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNodeAndMode([.tree]))
        )
    }

    private static func toggleFocusedAreaEdgeShapeStyleDefinition() -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "toggleFocusedAreaEdgeShapeStyle"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Area",
                verb: "Toggle Edge Shape"
            ),
            gesture: CanvasShortcutGesture(key: .character("e"), modifiers: [.command, .shift]),
            action: .apply(commands: [.toggleFocusedAreaEdgeShapeStyle]),
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: .character("e"), modifiers: [.command, .shift])
            ),
            searchTokens: ["area", "edge", "shape", "style", "curved", "straight", "toggle"],
            commandPaletteVisibility: .requiresFocusedNode,
            executionCondition: .all([
                .targetKinds([.node, .edge, .area]),
                .requiresFocusedNode,
            ])
        )
    }

    static func zoomDefinitions() -> [CanvasShortcutDefinition] {
        [
            zoomInDefinition(id: "zoomIn.commandPlus", key: .character("+"), modifiers: [.command], keyLabel: "+"),
            zoomInDefinition(
                id: "zoomIn.commandShiftSemicolon",
                key: .character(";"),
                modifiers: [.command, .shift],
                keyLabel: "+"
            ),
            zoomInDefinition(
                id: "zoomIn.commandShiftEquals",
                key: .character("="),
                modifiers: [.command, .shift],
                keyLabel: "+"
            ),
            zoomInDefinition(id: "zoomIn.commandEquals", key: .character("="), modifiers: [.command]),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomOut.commandMinus"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Viewport", verb: "Zoom Out"),
                gesture: CanvasShortcutGesture(key: .character("-"), modifiers: [.command]),
                action: .zoomOut,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("-"), modifiers: [.command])
                ),
                searchTokens: ["zoom", "out", "scale"]
            ),
        ]
    }

    private static func zoomInDefinition(
        id: String,
        key: CanvasShortcutKey,
        modifiers: CanvasShortcutModifiers,
        keyLabel: String? = nil
    ) -> CanvasShortcutDefinition {
        let gesture = CanvasShortcutGesture(key: key, modifiers: modifiers)
        return CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: id),
            commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Viewport", verb: "Zoom In"),
            gesture: gesture,
            action: .zoomIn,
            shortcutLabel: keyLabel.map { shortcutLabel(modifiers: modifiers, keyLabel: $0) }
                ?? shortcutLabel(for: gesture),
            searchTokens: ["zoom", "in", "scale"]
        )
    }

    static func shortcutLabel(for gesture: CanvasShortcutGesture) -> String {
        shortcutLabel(modifiers: gesture.modifiers, keyLabel: keyLabel(for: gesture.key))
    }

    static func shortcutLabel(modifiers: CanvasShortcutModifiers, keyLabel: String) -> String {
        modifierSymbols(for: modifiers).joined() + keyLabel
    }

    private static func modifierSymbols(for modifiers: CanvasShortcutModifiers) -> [String] {
        [
            modifiers.contains(.command) ? "⌘" : nil,
            modifiers.contains(.shift) ? "⇧" : nil,
            modifiers.contains(.control) ? "⌃" : nil,
            modifiers.contains(.option) ? "⌥" : nil,
            modifiers.contains(.function) ? "fn" : nil,
        ].compactMap { $0 }
    }

    private static func keyLabel(for key: CanvasShortcutKey) -> String {
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
}
