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
    /// Returns command-palette visible shortcuts for a runtime context.
    /// - Parameter context: Runtime context used for label adaptation and fallback filtering.
    /// - Returns: Shortcut entries visible to command palette UI.
    public static func commandPaletteDefinitions(
        context: CanvasCommandPaletteContext
    ) -> [CanvasShortcutDefinition] {
        commandPaletteDefinitions(
            context: context,
            executionContext: KeymapExecutionContext(
                editingMode: context.activeEditingMode,
                operationTargetKind: .node,
                hasFocusedNode: context.hasFocusedNode
            )
        )
    }

    /// Returns command-palette visible shortcuts for a runtime context.
    /// - Parameters:
    ///   - context: Runtime context used for label adaptation.
    ///   - executionContext: Runtime context used for execution-policy filtering.
    /// - Returns: Shortcut entries visible to command palette UI.
    public static func commandPaletteDefinitions(
        context: CanvasCommandPaletteContext,
        executionContext: KeymapExecutionContext
    ) -> [CanvasShortcutDefinition] {
        defaultDefinitionsStorage.compactMap { definition in
            guard
                definition.isVisibleInCommandPalette,
                KeymapExecutionPolicyResolver.isEnabled(
                    definition: definition,
                    context: executionContext
                )
            else {
                return nil
            }
            return commandPaletteDefinition(definition, for: context)
        }
    }

    public static func definition(for action: CanvasShortcutAction) -> CanvasShortcutDefinition? {
        defaultDefinitionsStorage.first { $0.action == action }
    }

    public static func definition(for command: CanvasCommand) -> CanvasShortcutDefinition? {
        defaultDefinitionsStorage.first {
            guard case .apply(let commands) = $0.action else {
                return false
            }
            return commands.contains(where: { $0 == command })
        }
    }
}

extension CanvasShortcutCatalogService {
    static func nodeOrEdgeTargetCondition() -> KeymapExecutionCondition {
        .targetKinds([.node, .edge])
    }

    static func nodeOrEdgeTargetCondition(
        combinedWith condition: KeymapExecutionCondition
    ) -> KeymapExecutionCondition {
        .all([nodeOrEdgeTargetCondition(), condition])
    }

    static func nodeOrEdgeExecutionCondition(
        for visibility: CanvasCommandPaletteVisibility
    ) -> KeymapExecutionCondition {
        nodeOrEdgeTargetCondition(combinedWith: visibility.defaultExecutionCondition)
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
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Palette",
                    verb: "Open Command"
                ),
                gesture: CanvasShortcutGesture(key: .character("k"), modifiers: [.command]),
                action: .openCommandPalette,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("k"), modifiers: [.command])
                ),
                searchTokens: ["palette", "command"],
                isVisibleInCommandPalette: false
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "openCommandPalette.commandShiftP"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Palette",
                    verb: "Open Command"
                ),
                gesture: CanvasShortcutGesture(key: .character("p"), modifiers: [.command, .shift]),
                action: .openCommandPalette,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("p"), modifiers: [.command, .shift])
                ),
                searchTokens: ["palette", "command"],
                isVisibleInCommandPalette: false
            ),
        ]
    }

    private static func nodeEditingDefinitions() -> [CanvasShortcutDefinition] {
        baseNodeCreationDefinitions() + baseNodeMutationDefinitions() + clipboardNodeEditingDefinitions()
    }
    private static func baseNodeCreationDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addChildNode"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Add Child"),
                gesture: CanvasShortcutGesture(key: .enter, modifiers: [.command]),
                action: .apply(commands: [.addChildNode]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .enter, modifiers: [.command])
                ),
                commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree]),
                executionCondition: nodeOrEdgeTargetCondition()
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addNode"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Add"),
                gesture: CanvasShortcutGesture(key: .enter, modifiers: [.shift]),
                action: .apply(commands: [.addNode]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .enter, modifiers: [.shift])
                ),
                executionCondition: nodeOrEdgeTargetCondition()
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addSiblingNodeAbove"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Node",
                    verb: "Add Sibling Above"
                ),
                gesture: CanvasShortcutGesture(key: .enter, modifiers: [.option]),
                action: .apply(commands: [.addSiblingNode(position: .above)]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .enter, modifiers: [.option])
                ),
                commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree]),
                executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNodeAndMode([.tree]))
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "addSiblingNodeBelow"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Node",
                    verb: "Add Sibling Below"
                ),
                gesture: CanvasShortcutGesture(key: .enter, modifiers: []),
                action: .apply(commands: [.addSiblingNode(position: .below)]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .enter, modifiers: [])
                ),
                commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree]),
                executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNodeAndMode([.tree]))
            ),
        ]
    }

    private static func baseNodeMutationDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "deleteSelectedOrFocusedNodes"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Delete Selected"),
                gesture: CanvasShortcutGesture(key: .deleteBackward, modifiers: []),
                action: .apply(commands: [.deleteSelectedOrFocusedNodes]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .deleteBackward, modifiers: [])
                ),
                commandPaletteVisibility: .requiresFocusedNode,
                executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode),
                executionRoute: .edgeAware
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "duplicateSelectionAsSibling"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Node",
                    verb: "Duplicate Selection As Sibling"
                ),
                gesture: CanvasShortcutGesture(key: .character("d"), modifiers: [.command]),
                action: .apply(commands: [.duplicateSelectionAsSibling]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("d"), modifiers: [.command])
                ),
                searchTokens: ["duplicate", "selection", "sibling", "tree"],
                commandPaletteVisibility: .requiresFocusedNodeAndMode([.tree]),
                executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNodeAndMode([.tree]))
            ),
        ]
    }

    private static func clipboardNodeEditingDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "copySelectionOrFocusedSubtree"),
                commandPaletteLabel: CanvasCommandPaletteLabel(
                    noun: "Node",
                    verb: "Copy Selected"
                ),
                gesture: CanvasShortcutGesture(key: .character("c"), modifiers: [.command]),
                action: .apply(commands: [.copySelectionOrFocusedSubtree]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("c"), modifiers: [.command])
                ),
                searchTokens: ["copy", "selected", "subtree", "node"],
                commandPaletteVisibility: .requiresFocusedNode,
                executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode)
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "cutSelectionOrFocusedSubtree"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Cut Selected"),
                gesture: CanvasShortcutGesture(key: .character("x"), modifiers: [.command]),
                action: .apply(commands: [.cutSelectionOrFocusedSubtree]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("x"), modifiers: [.command])
                ),
                searchTokens: ["cut", "selected", "subtree", "node"],
                commandPaletteVisibility: .requiresFocusedNode,
                executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode)
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "pasteClipboardAtFocusedNode"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Node", verb: "Paste"),
                gesture: CanvasShortcutGesture(key: .character("v"), modifiers: [.command]),
                action: .apply(commands: [.pasteClipboardAtFocusedNode]),
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("v"), modifiers: [.command])
                ),
                searchTokens: ["paste", "selected", "subtree", "child", "node"],
                commandPaletteVisibility: .requiresFocusedNode,
                executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode)
            ),
        ]
    }

    private static func navigationDefinitions() -> [CanvasShortcutDefinition] {
        focusNavigationDefinitions()
            + nodeNavigationDefinitions()
            + canvasNavigationDefinitions()
    }

    private static func focusNavigationDefinitions() -> [CanvasShortcutDefinition] {
        focusMoveDefinitions() + focusExtendDefinitions() + focusMoveAcrossAreasDefinitions()
    }

    private static func focusMoveDefinitions() -> [CanvasShortcutDefinition] {
        [
            focusMoveDefinition(direction: .down, key: .arrowDown),
            focusMoveDefinition(direction: .left, key: .arrowLeft),
            focusMoveDefinition(direction: .right, key: .arrowRight),
            focusMoveDefinition(direction: .up, key: .arrowUp),
        ]
    }

    private static func focusExtendDefinitions() -> [CanvasShortcutDefinition] {
        [
            focusExtendDefinition(direction: .down, key: .arrowDown),
            focusExtendDefinition(direction: .left, key: .arrowLeft),
            focusExtendDefinition(direction: .right, key: .arrowRight),
            focusExtendDefinition(direction: .up, key: .arrowUp),
        ]
    }

    private static func focusMoveDefinition(
        direction: CanvasFocusDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "moveFocus\(focusDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Focus",
                verb: "Move \(focusDirectionLabel(direction))"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: []),
            action: .apply(commands: [.moveFocus(direction)]),
            shortcutLabel: shortcutLabel(for: CanvasShortcutGesture(key: key, modifiers: [])),
            commandPaletteVisibility: .requiresFocusedNode,
            executionRoute: .edgeAware
        )
    }

    private static func focusExtendDefinition(
        direction: CanvasFocusDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "extendSelection\(focusDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Selection",
                verb: "Extend \(focusDirectionLabel(direction))"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: [.shift]),
            action: .apply(commands: [.extendSelection(direction)]),
            shortcutLabel: shortcutLabel(for: CanvasShortcutGesture(key: key, modifiers: [.shift])),
            commandPaletteVisibility: .requiresFocusedNode,
            executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode),
            executionRoute: .edgeAware
        )
    }

    private static func nodeNavigationDefinitions() -> [CanvasShortcutDefinition] {
        nodeMoveDefinitions() + nodeNudgeDefinitions() + nodeScaleDefinitions()
    }

    private static func nodeMoveDefinitions() -> [CanvasShortcutDefinition] {
        [
            nodeMoveDefinition(direction: .down, key: .arrowDown),
            nodeMoveDefinition(direction: .left, key: .arrowLeft),
            nodeMoveDefinition(direction: .right, key: .arrowRight),
            nodeMoveDefinition(direction: .up, key: .arrowUp),
        ]
    }

    private static func nodeNudgeDefinitions() -> [CanvasShortcutDefinition] {
        [
            nodeNudgeDefinition(direction: .down, key: .arrowDown),
            nodeNudgeDefinition(direction: .left, key: .arrowLeft),
            nodeNudgeDefinition(direction: .right, key: .arrowRight),
            nodeNudgeDefinition(direction: .up, key: .arrowUp),
        ]
    }

    private static func nodeMoveDefinition(
        direction: CanvasNodeMoveDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "moveNode\(nodeDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Node",
                verb: "Move \(nodeDirectionLabel(direction))"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: [.command]),
            action: .apply(commands: [.moveNode(direction)]),
            shortcutLabel: shortcutLabel(for: CanvasShortcutGesture(key: key, modifiers: [.command])),
            commandPaletteVisibility: .requiresFocusedNode,
            executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNode)
        )
    }

    private static func nodeNudgeDefinition(
        direction: CanvasNodeMoveDirection,
        key: CanvasShortcutKey
    ) -> CanvasShortcutDefinition {
        CanvasShortcutDefinition(
            id: CanvasShortcutID(rawValue: "nudgeNode\(nodeDirectionIDSuffix(direction))"),
            commandPaletteLabel: CanvasCommandPaletteLabel(
                noun: "Node",
                verb: "Move \(nodeDirectionLabel(direction)) Slightly"
            ),
            gesture: CanvasShortcutGesture(key: key, modifiers: [.command, .shift]),
            action: .apply(commands: [.nudgeNode(direction)]),
            shortcutLabel: shortcutLabel(
                for: CanvasShortcutGesture(key: key, modifiers: [.command, .shift])
            ),
            searchTokens: ["move", "slightly", "nudge", "grid"],
            commandPaletteVisibility: .requiresFocusedNodeAndMode([.diagram]),
            executionCondition: nodeOrEdgeExecutionCondition(for: .requiresFocusedNodeAndMode([.diagram]))
        )
    }

    private static func canvasNavigationDefinitions() -> [CanvasShortcutDefinition] {
        [
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
            ),
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
            ),
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
            ),
        ]
    }

    private static func historyDefinitions() -> [CanvasShortcutDefinition] {
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

    private static func zoomDefinitions() -> [CanvasShortcutDefinition] {
        [
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomIn.commandPlus"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Viewport", verb: "Zoom In"),
                gesture: CanvasShortcutGesture(key: .character("+"), modifiers: [.command]),
                action: .zoomIn,
                shortcutLabel: shortcutLabel(modifiers: [.command], keyLabel: "+"),
                searchTokens: ["zoom", "in", "scale"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomIn.commandShiftSemicolon"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Viewport", verb: "Zoom In"),
                gesture: CanvasShortcutGesture(key: .character(";"), modifiers: [.command, .shift]),
                action: .zoomIn,
                shortcutLabel: shortcutLabel(modifiers: [.command], keyLabel: "+"),
                searchTokens: ["zoom", "in", "scale"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomIn.commandShiftEquals"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Viewport", verb: "Zoom In"),
                gesture: CanvasShortcutGesture(key: .character("="), modifiers: [.command, .shift]),
                action: .zoomIn,
                shortcutLabel: shortcutLabel(modifiers: [.command], keyLabel: "+"),
                searchTokens: ["zoom", "in", "scale"]
            ),
            CanvasShortcutDefinition(
                id: CanvasShortcutID(rawValue: "zoomIn.commandEquals"),
                commandPaletteLabel: CanvasCommandPaletteLabel(noun: "Viewport", verb: "Zoom In"),
                gesture: CanvasShortcutGesture(key: .character("="), modifiers: [.command]),
                action: .zoomIn,
                shortcutLabel: shortcutLabel(
                    for: CanvasShortcutGesture(key: .character("="), modifiers: [.command])
                ),
                searchTokens: ["zoom", "in", "scale"]
            ),
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

    private static func shortcutLabel(for gesture: CanvasShortcutGesture) -> String {
        shortcutLabel(modifiers: gesture.modifiers, keyLabel: keyLabel(for: gesture.key))
    }

    private static func shortcutLabel(modifiers: CanvasShortcutModifiers, keyLabel: String) -> String {
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
