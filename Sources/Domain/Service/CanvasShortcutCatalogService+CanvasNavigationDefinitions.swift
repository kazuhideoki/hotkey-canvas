// Background: Canvas-level navigation shortcuts span connect mode, viewport focus, and fold/style actions.
// Responsibility: Provide non-node-mutation navigation shortcut definitions.
extension CanvasShortcutCatalogService {
    static func canvasNavigationDefinitions() -> [CanvasShortcutDefinition] {
        [
            connectFocusedNodeDefinition(),
            centerFocusedNodeDefinition(),
            toggleFoldFocusedSubtreeDefinition(),
            toggleFocusedAreaEdgeShapeDefinition(),
        ]
    }

    private static func connectFocusedNodeDefinition() -> CanvasShortcutDefinition {
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

    private static func toggleFocusedAreaEdgeShapeDefinition() -> CanvasShortcutDefinition {
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
}
