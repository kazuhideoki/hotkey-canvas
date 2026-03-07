import Domain

// Background: Canvas editing supports multiple command kinds behind a single apply entry point.
// Responsibility: Dispatch each command to the corresponding operation handler.
extension ApplyCanvasCommandsUseCase {
    /// Dispatches one command to its mutation handler and returns stage effects with the result graph.
    func applyMutation(command: CanvasCommand, to graph: CanvasGraph) throws -> CanvasMutationResult {
<<<<<<< HEAD
        try CanvasAreaMembershipService.validate(in: graph).get()
        let resolvedContext = try resolvedCommandContext(for: command, in: graph)
        guard isCommandSupported(resolvedContext.command, supportedIn: resolvedContext.area.editingMode) else {
            throw CanvasAreaPolicyError.unsupportedCommandInMode(
                mode: resolvedContext.area.editingMode,
                command: resolvedContext.command
            )
        }
        guard isCommandExecutionAllowed(resolvedContext.command, context: resolvedContext.executionContext) else {
            return noOpMutationResult(for: graph)
        }

        if Self.isAreaManagementCommand(resolvedContext.command) {
            return try applyAreaManagementCommand(command: resolvedContext.command, to: graph)
=======
        let dispatchContext = try makeDispatchContext(
            command: command,
            in: graph,
        )
        guard isCommandSupported(dispatchContext.command, supportedIn: dispatchContext.area.editingMode) else {
            throw CanvasAreaPolicyError.unsupportedCommandInMode(
                mode: dispatchContext.area.editingMode,
                command: dispatchContext.command
            )
        }
        guard isCommandExecutionAllowed(dispatchContext.command, context: dispatchContext.executionContext) else {
            return noOpMutationResult(for: graph)
        }

        switch dispatchContext.command {
        case .toggleFocusedAreaEdgeShapeStyle, .convertFocusedAreaMode, .createArea, .assignNodesToArea:
            return try applyAreaManagementCommand(command: dispatchContext.command, to: graph)
        default:
            return try applyGraphEditingCommand(
                command: dispatchContext.command,
                to: graph,
                resolvedAreaID: dispatchContext.area.id,
                resolvedAreaMode: dispatchContext.area.editingMode
            )
>>>>>>> main
        }
        return try applyGraphEditingCommand(
            command: resolvedContext.command,
            to: graph,
            resolvedAreaID: resolvedContext.areaID,
            resolvedAreaMode: resolvedContext.area.editingMode
        )
    }

    private func makeDispatchContext(
        command: CanvasCommand,
        in graph: CanvasGraph
    ) throws -> CommandDispatchContext {
        try CanvasAreaMembershipService.validate(in: graph).get()
        let normalizedCommand = normalize(command: command, in: graph)
        let resolvedAreaID = try resolveAreaID(for: normalizedCommand, in: graph).get()
        let resolvedArea = try CanvasAreaMembershipService.area(withID: resolvedAreaID, in: graph).get()
        let executionContext = makeExecutionContext(
            for: normalizedCommand,
            in: graph,
            editingMode: resolvedArea.editingMode
        )
        return CommandDispatchContext(
            command: normalizedCommand,
            area: resolvedArea,
            executionContext: executionContext
        )
    }

    private func applyGraphEditingCommand(
        command: CanvasCommand,
        to graph: CanvasGraph,
        resolvedAreaID: CanvasAreaID,
        resolvedAreaMode: CanvasEditingMode
    ) throws -> CanvasMutationResult {
        if let focusCommandResult = applyFocusCommand(command: command, to: graph) {
            return focusCommandResult
        }
<<<<<<< HEAD
        if Self.isNodeStructureCommand(command) {
=======
        if let movementResult = try applyMovementOrViewportCommand(
            command: command,
            to: graph,
            resolvedAreaID: resolvedAreaID,
            resolvedAreaMode: resolvedAreaMode
        ) {
            return movementResult
        }
        return try applyRemainingGraphEditingCommand(
            command: command,
            to: graph,
            resolvedAreaID: resolvedAreaID,
            resolvedAreaMode: resolvedAreaMode
        )
    }

    private func applyRemainingGraphEditingCommand(
        command: CanvasCommand,
        to graph: CanvasGraph,
        resolvedAreaID: CanvasAreaID,
        resolvedAreaMode: CanvasEditingMode
    ) throws -> CanvasMutationResult {
        switch command {
        case .addNode, .addChildNode, .addSiblingNode, .duplicateSelectionAsSibling, .connectNodes:
>>>>>>> main
            return try applyNodeStructureCommand(
                command: command,
                to: graph,
                resolvedAreaID: resolvedAreaID
            )
        }
        if let commandResult = try applyAreaOrNodeMutationCommand(
            command: command,
            to: graph,
            resolvedAreaID: resolvedAreaID,
            resolvedAreaMode: resolvedAreaMode
        ) {
            return commandResult
        }
        if let contentCommandResult = try applyContentCommand(command: command, to: graph) {
            return contentCommandResult
        }
        return noOpMutationResult(for: graph)
    }

    private func applyAreaOrNodeMutationCommand(
        command: CanvasCommand,
        to graph: CanvasGraph,
        resolvedAreaID: CanvasAreaID,
        resolvedAreaMode: CanvasEditingMode
    ) throws -> CanvasMutationResult? {
        switch command {
        case .alignAllAreasVertically:
            return alignAllAreasVertically(in: graph, areaID: resolvedAreaID)
        case .moveArea(let direction):
            return moveArea(
                in: graph,
                areaID: resolvedAreaID,
                direction: direction
            )
        case .moveNode(let direction):
            return try moveNode(
                in: graph,
                direction: direction,
                areaMode: resolvedAreaMode
            )
        case .nudgeNode(let direction):
            return nudgeNode(
                in: graph,
                direction: direction,
                areaMode: resolvedAreaMode
            )
        case .alignSelectedNodes(let axis):
            return try alignSelectedNodes(
                in: graph,
                axis: axis,
                areaMode: resolvedAreaMode
            )
        case .toggleFoldFocusedSubtree:
            return toggleFoldFocusedSubtree(in: graph)
        case .cycleFocusedEdgeDirectionality(let focusedEdge, let selectedEdgeIDs):
            return cycleFocusedEdgeDirectionality(
                in: graph,
                focusedEdge: focusedEdge,
                selectedEdgeIDs: selectedEdgeIDs
            )
        case .deleteSelectedOrFocusedNodes, .deleteSelectedOrFocusedEdges:
            return try applyDeleteCommand(
                command: command,
                in: graph,
                resolvedAreaID: resolvedAreaID,
                resolvedAreaMode: resolvedAreaMode
            )
<<<<<<< HEAD
        case .centerFocusedNode:
            return noOpMutationResult(for: graph)
        default:
            return nil
        }
    }

    private func applyContentCommand(
        command: CanvasCommand,
        to graph: CanvasGraph
    ) throws -> CanvasMutationResult? {
        switch command {
        case .copySelectionOrFocusedSubtree:
            return copySelectionOrFocusedSubtree(in: graph)
        case .cutSelectionOrFocusedSubtree:
            return try cutSelectionOrFocusedSubtree(in: graph)
        case .pasteClipboardAtFocusedNode:
            return try pasteClipboardAtFocusedNode(in: graph)
=======
        case .copySelectionOrFocusedSubtree, .cutSelectionOrFocusedSubtree, .pasteClipboardAtFocusedNode:
            return try applyClipboardCommand(command: command, to: graph)
>>>>>>> main
        case .setNodeText, .upsertNodeAttachment, .toggleFocusedNodeMarkdownStyle, .scaleSelectedNodes:
            return try applyNodeContentCommand(command: command, to: graph)
        case .setEdgeLabel(let edgeID, let label):
            return setEdgeLabel(in: graph, edgeID: edgeID, label: label)
        default:
<<<<<<< HEAD
=======
            return noOpMutationResult(for: graph)
        }
    }

    private func applyMovementOrViewportCommand(
        command: CanvasCommand,
        to graph: CanvasGraph,
        resolvedAreaID: CanvasAreaID,
        resolvedAreaMode: CanvasEditingMode
    ) throws -> CanvasMutationResult? {
        switch command {
        case .alignAllAreasVertically:
            return alignAllAreasVertically(in: graph, areaID: resolvedAreaID)
        case .moveArea(let direction):
            return moveArea(in: graph, areaID: resolvedAreaID, direction: direction)
        case .moveNode(let direction):
            return try moveNode(in: graph, direction: direction, areaMode: resolvedAreaMode)
        case .nudgeNode(let direction):
            return nudgeNode(in: graph, direction: direction, areaMode: resolvedAreaMode)
        case .alignSelectedNodes(let axis):
            return try alignSelectedNodes(in: graph, axis: axis, areaMode: resolvedAreaMode)
        case .toggleFoldFocusedSubtree:
            return toggleFoldFocusedSubtree(in: graph)
        case .centerFocusedNode:
            return noOpMutationResult(for: graph)
        default:
>>>>>>> main
            return nil
        }
    }

    private func applyFocusCommand(
        command: CanvasCommand,
        to graph: CanvasGraph
    ) -> CanvasMutationResult? {
        switch command {
        case .moveFocus(let direction):
            return moveFocus(in: graph, direction: direction)
        case .moveFocusAcrossAreasToRoot(let direction):
            return moveFocusAcrossAreasToRoot(in: graph, direction: direction)
        case .focusNode(let nodeID):
            return focusNode(in: graph, nodeID: nodeID)
        case .focusArea(let areaID):
            return focusArea(in: graph, areaID: areaID)
        case .extendSelection(let direction):
            return extendSelection(in: graph, direction: direction)
        default:
            return nil
        }
    }

    private func applyDeleteCommand(
        command: CanvasCommand,
        in graph: CanvasGraph,
        resolvedAreaID: CanvasAreaID,
        resolvedAreaMode: CanvasEditingMode
    ) throws -> CanvasMutationResult {
        switch command {
        case .deleteSelectedOrFocusedNodes:
            return try deleteSelectedOrFocusedNodes(
                in: graph,
                areaID: resolvedAreaID,
                areaMode: resolvedAreaMode
            )
        case .deleteSelectedOrFocusedEdges(let focusedEdge, let selectedEdgeIDs):
            return try deleteSelectedOrFocusedEdges(
                in: graph,
                focusedEdge: focusedEdge,
                selectedEdgeIDs: selectedEdgeIDs
            )
        case .cycleFocusedEdgeDirectionality:
            return noOpMutationResult(for: graph)
        case .addNode,
            .addChildNode,
            .addSiblingNode,
            .duplicateSelectionAsSibling,
            .connectNodes,
            .alignAllAreasVertically,
            .moveFocus,
            .moveFocusAcrossAreasToRoot,
            .focusNode,
            .focusArea,
            .extendSelection,
            .moveArea,
            .moveNode,
            .nudgeNode,
            .alignSelectedNodes,
            .scaleSelectedNodes,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .copySelectionOrFocusedSubtree,
            .cutSelectionOrFocusedSubtree,
            .pasteClipboardAtFocusedNode,
            .setNodeText,
            .setEdgeLabel,
            .upsertNodeAttachment,
            .toggleFocusedNodeMarkdownStyle,
            .toggleFocusedAreaEdgeShapeStyle,
            .convertFocusedAreaMode,
            .createArea,
            .assignNodesToArea:
            return noOpMutationResult(for: graph)
        }
    }

    private func applyClipboardCommand(
        command: CanvasCommand,
        to graph: CanvasGraph
    ) throws -> CanvasMutationResult {
        switch command {
        case .copySelectionOrFocusedSubtree:
            return copySelectionOrFocusedSubtree(in: graph)
        case .cutSelectionOrFocusedSubtree:
            return try cutSelectionOrFocusedSubtree(in: graph)
        case .pasteClipboardAtFocusedNode:
            return try pasteClipboardAtFocusedNode(in: graph)
        default:
            return noOpMutationResult(for: graph)
        }
    }

    private func applyNodeStructureCommand(
        command: CanvasCommand,
        to graph: CanvasGraph,
        resolvedAreaID: CanvasAreaID
    ) throws -> CanvasMutationResult {
        switch command {
        case .addNode:
            return try addNode(in: graph, areaID: resolvedAreaID)
        case .addChildNode:
            return try addChildNode(in: graph, requiresTopLevelParent: false)
        case .addSiblingNode(let position):
            return try addSiblingNode(in: graph, position: position)
        case .duplicateSelectionAsSibling:
            return try duplicateSelectionAsSibling(in: graph, resolvedAreaID: resolvedAreaID)
        case .connectNodes(let fromNodeID, let toNodeID):
            return try connectNodes(
                in: graph,
                fromNodeID: fromNodeID,
                toNodeID: toNodeID
            )
        case .alignAllAreasVertically,
            .moveFocus,
            .moveFocusAcrossAreasToRoot,
            .focusNode,
            .focusArea,
            .extendSelection,
            .moveArea,
            .moveNode,
            .nudgeNode,
            .alignSelectedNodes,
            .scaleSelectedNodes,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .cycleFocusedEdgeDirectionality,
            .deleteSelectedOrFocusedNodes,
            .deleteSelectedOrFocusedEdges,
            .copySelectionOrFocusedSubtree,
            .cutSelectionOrFocusedSubtree,
            .pasteClipboardAtFocusedNode,
            .setNodeText,
            .setEdgeLabel,
            .upsertNodeAttachment,
            .toggleFocusedNodeMarkdownStyle,
            .toggleFocusedAreaEdgeShapeStyle,
            .convertFocusedAreaMode,
            .createArea,
            .assignNodesToArea:
            return noOpMutationResult(for: graph)
        }
    }

    private func applyNodeContentCommand(
        command: CanvasCommand,
        to graph: CanvasGraph
    ) throws -> CanvasMutationResult {
        switch command {
        case .setNodeText(let nodeID, let text, let nodeHeight):
            return try setNodeText(in: graph, nodeID: nodeID, text: text, nodeHeight: nodeHeight)
        case .upsertNodeAttachment(let nodeID, let attachment, let nodeWidth, let nodeHeight):
            return try upsertNodeAttachment(
                in: graph,
                nodeID: nodeID,
                attachment: attachment,
                nodeWidth: nodeWidth,
                nodeHeight: nodeHeight
            )
        case .toggleFocusedNodeMarkdownStyle:
            return try toggleFocusedNodeMarkdownStyle(in: graph)
        case .scaleSelectedNodes(let direction):
            return try scaleSelectedNodes(
                in: graph,
                direction: direction
            )
        case .addNode,
            .addChildNode,
            .addSiblingNode,
            .duplicateSelectionAsSibling,
            .connectNodes,
            .alignAllAreasVertically,
            .moveFocus,
            .moveFocusAcrossAreasToRoot,
            .focusNode,
            .focusArea,
            .extendSelection,
            .moveArea,
            .moveNode,
            .nudgeNode,
            .alignSelectedNodes,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .cycleFocusedEdgeDirectionality,
            .deleteSelectedOrFocusedNodes,
            .deleteSelectedOrFocusedEdges,
            .copySelectionOrFocusedSubtree,
            .cutSelectionOrFocusedSubtree,
            .pasteClipboardAtFocusedNode,
            .setEdgeLabel,
            .toggleFocusedAreaEdgeShapeStyle,
            .convertFocusedAreaMode,
            .createArea,
            .assignNodesToArea:
            return noOpMutationResult(for: graph)
        }
    }

    private func applyAreaManagementCommand(
        command: CanvasCommand,
        to graph: CanvasGraph
    ) throws -> CanvasMutationResult {
        switch command {
        case .toggleFocusedAreaEdgeShapeStyle:
            let graphAfterMutation = try CanvasAreaMembershipService.toggleFocusedAreaEdgeShapeStyle(
                in: graph
            ).get()
            return areaManagementMutationResult(graphBeforeMutation: graph, graphAfterMutation: graphAfterMutation)
        case .convertFocusedAreaMode(let mode):
            let graphAfterMutation = try CanvasAreaMembershipService.convertFocusedAreaMode(
                to: mode,
                in: graph
            ).get()
            return areaManagementMutationResult(graphBeforeMutation: graph, graphAfterMutation: graphAfterMutation)
        case .createArea(let id, let mode, let nodeIDs):
            let graphAfterMutation = try CanvasAreaMembershipService.createArea(
                id: id, mode: mode, nodeIDs: nodeIDs, in: graph
            ).get()
            return areaManagementMutationResult(graphBeforeMutation: graph, graphAfterMutation: graphAfterMutation)
        case .assignNodesToArea(let nodeIDs, let areaID):
            let graphAfterMutation = try CanvasAreaMembershipService.assign(
                nodeIDs: nodeIDs,
                to: areaID,
                in: graph
            ).get()
            return areaManagementMutationResult(graphBeforeMutation: graph, graphAfterMutation: graphAfterMutation)
        case .addNode,
            .addChildNode,
            .addSiblingNode,
            .duplicateSelectionAsSibling,
            .connectNodes,
            .alignAllAreasVertically,
            .moveFocus,
            .moveFocusAcrossAreasToRoot,
            .focusNode,
            .focusArea,
            .extendSelection,
            .moveArea,
            .moveNode,
            .nudgeNode,
            .alignSelectedNodes,
            .scaleSelectedNodes,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .cycleFocusedEdgeDirectionality,
            .deleteSelectedOrFocusedNodes,
            .deleteSelectedOrFocusedEdges,
            .copySelectionOrFocusedSubtree,
            .cutSelectionOrFocusedSubtree,
            .pasteClipboardAtFocusedNode,
            .setNodeText,
            .setEdgeLabel,
            .upsertNodeAttachment,
            .toggleFocusedNodeMarkdownStyle:
            return noOpMutationResult(for: graph)
        }
    }

    private func areaManagementMutationResult(
        graphBeforeMutation: CanvasGraph,
        graphAfterMutation: CanvasGraph
    ) -> CanvasMutationResult {
        CanvasMutationResult(
            graphBeforeMutation: graphBeforeMutation,
            graphAfterMutation: graphAfterMutation,
            effects: CanvasMutationEffects(
                didMutateGraph: graphAfterMutation != graphBeforeMutation,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: false
            )
        )
    }

    private func isCommandSupported(_ command: CanvasCommand, supportedIn mode: CanvasEditingMode) -> Bool {
        switch mode {
        case .tree:
            return TreeAreaPolicyService.supports(command)
        case .diagram:
            return DiagramAreaPolicyService.supports(command)
        }
    }

    private func isCommandExecutionAllowed(
        _ command: CanvasCommand,
        context: KeymapExecutionContext
    ) -> Bool {
        guard let definition = CanvasShortcutCatalogService.definition(for: command) else {
            return true
        }
        return KeymapExecutionPolicyResolver.isEnabled(
            definition: definition,
            context: context
        )
    }

    func makeExecutionContext(
        for command: CanvasCommand,
        in graph: CanvasGraph,
        editingMode: CanvasEditingMode
    ) -> KeymapExecutionContext {
        KeymapExecutionContext(
            editingMode: editingMode,
            operationTargetKind: operationTargetKind(
                for: command,
                in: graph,
                editingMode: editingMode
            ),
            hasFocusedNode: graph.focusedNodeID != nil,
            isEditingText: false,
            isCommandPalettePresented: false,
            isSearchPresented: false,
            isConnectNodeSelectionActive: false,
            isAddNodePopupPresented: false,
            selectedNodeCount: graph.selectedNodeIDs.count,
            selectedEdgeCount: graph.selectedEdgeIDs.count
        )
    }
<<<<<<< HEAD

    private func operationTargetKind(
        for command: CanvasCommand,
        in graph: CanvasGraph,
        editingMode: CanvasEditingMode
    ) -> KeymapSwitchTargetKindIntentVariant {
        if case .edge = graph.focusedElement {
            return .edge
        }

        switch command {
        case .deleteSelectedOrFocusedEdges, .cycleFocusedEdgeDirectionality, .setEdgeLabel:
            return .edge
        case .focusArea:
            return .area
        default:
            if case .area = graph.focusedElement {
                guard let definition = CanvasShortcutCatalogService.definition(for: command) else {
                    return .area
                }
                let areaContext = KeymapExecutionContext(
                    editingMode: editingMode,
                    operationTargetKind: .area,
                    hasFocusedNode: graph.focusedNodeID != nil,
                    isEditingText: false,
                    isCommandPalettePresented: false,
                    isSearchPresented: false,
                    isConnectNodeSelectionActive: false,
                    isAddNodePopupPresented: false,
                    selectedNodeCount: graph.selectedNodeIDs.count,
                    selectedEdgeCount: graph.selectedEdgeIDs.count
                )
                if KeymapExecutionPolicyResolver.isEnabled(
                    definition: definition,
                    context: areaContext
                ) {
                    return .area
                }
            }
            return .node
        }
    }

=======
>>>>>>> main
}
