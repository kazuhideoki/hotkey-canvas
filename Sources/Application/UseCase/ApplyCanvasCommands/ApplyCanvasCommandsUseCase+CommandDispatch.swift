import Domain

// Background: Canvas editing supports multiple command kinds behind a single apply entry point.
// Responsibility: Dispatch each command to the corresponding operation handler.
extension ApplyCanvasCommandsUseCase {
    /// Dispatches one command to its mutation handler and returns stage effects with the result graph.
    func applyMutation(command: CanvasCommand, to graph: CanvasGraph) throws -> CanvasMutationResult {
        try CanvasAreaMembershipService.validate(in: graph).get()
        let normalizedCommand = normalize(
            command: command,
            in: graph
        )
        let resolvedAreaID = try resolveAreaID(for: normalizedCommand, in: graph).get()
        let resolvedArea = try CanvasAreaMembershipService.area(withID: resolvedAreaID, in: graph).get()
        let executionContext = makeExecutionContext(
            for: normalizedCommand,
            in: graph,
            editingMode: resolvedArea.editingMode
        )
        guard isCommandSupported(normalizedCommand, supportedIn: resolvedArea.editingMode) else {
            throw CanvasAreaPolicyError.unsupportedCommandInMode(
                mode: resolvedArea.editingMode,
                command: normalizedCommand
            )
        }
        guard isCommandExecutionAllowed(normalizedCommand, context: executionContext) else {
            return noOpMutationResult(for: graph)
        }

        switch normalizedCommand {
        case .convertFocusedAreaMode, .createArea, .assignNodesToArea:
            return try applyAreaManagementCommand(command: normalizedCommand, to: graph)
        default:
            return try applyGraphEditingCommand(
                command: normalizedCommand,
                to: graph,
                resolvedAreaID: resolvedAreaID,
                resolvedAreaMode: resolvedArea.editingMode
            )
        }
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

        switch command {
        case .addNode, .addChildNode, .addSiblingNode, .duplicateSelectionAsSibling, .connectNodes:
            return try applyNodeStructureCommand(
                command: command,
                to: graph,
                resolvedAreaID: resolvedAreaID
            )
        case .alignAllAreasVertically:
            return alignAllAreasVertically(in: graph, areaID: resolvedAreaID)
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
        case .toggleFoldFocusedSubtree:
            return toggleFoldFocusedSubtree(in: graph)
        case .centerFocusedNode:
            return noOpMutationResult(for: graph)
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
        case .copySelectionOrFocusedSubtree:
            return copySelectionOrFocusedSubtree(in: graph)
        case .cutSelectionOrFocusedSubtree:
            return try cutSelectionOrFocusedSubtree(in: graph)
        case .pasteClipboardAtFocusedNode:
            return try pasteClipboardAtFocusedNode(in: graph)
        case .setNodeText, .upsertNodeAttachment, .toggleFocusedNodeMarkdownStyle, .scaleSelectedNodes:
            return try applyNodeContentCommand(command: command, to: graph)
        case .convertFocusedAreaMode, .createArea, .assignNodesToArea:
            return noOpMutationResult(for: graph)
        case .moveFocus, .moveFocusAcrossAreasToRoot, .focusNode, .focusArea, .extendSelection:
            return noOpMutationResult(for: graph)
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
            .moveNode,
            .nudgeNode,
            .scaleSelectedNodes,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .copySelectionOrFocusedSubtree,
            .cutSelectionOrFocusedSubtree,
            .pasteClipboardAtFocusedNode,
            .setNodeText,
            .upsertNodeAttachment,
            .toggleFocusedNodeMarkdownStyle,
            .convertFocusedAreaMode,
            .createArea,
            .assignNodesToArea:
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
            .moveNode,
            .nudgeNode,
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
            .upsertNodeAttachment,
            .toggleFocusedNodeMarkdownStyle,
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
            .moveNode,
            .nudgeNode,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .cycleFocusedEdgeDirectionality,
            .deleteSelectedOrFocusedNodes,
            .deleteSelectedOrFocusedEdges,
            .copySelectionOrFocusedSubtree,
            .cutSelectionOrFocusedSubtree,
            .pasteClipboardAtFocusedNode,
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
            .moveNode,
            .nudgeNode,
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

    private func makeExecutionContext(
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

    private func operationTargetKind(
        for command: CanvasCommand,
        in graph: CanvasGraph,
        editingMode: CanvasEditingMode
    ) -> KeymapSwitchTargetKindIntentVariant {
        if case .edge = graph.focusedElement {
            return .edge
        }

        switch command {
        case .deleteSelectedOrFocusedEdges, .cycleFocusedEdgeDirectionality:
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

    private func resolveAreaID(
        for command: CanvasCommand,
        in graph: CanvasGraph
    ) -> Result<CanvasAreaID, CanvasAreaPolicyError> {
        switch command {
        case .addNode:
            if let focusedNodeID = graph.focusedNodeID, graph.nodesByID[focusedNodeID] != nil {
                return CanvasAreaMembershipService.areaID(containing: focusedNodeID, in: graph)
            }
            let sortedAreaIDs = graph.areasByID.keys.sorted(by: { $0.rawValue < $1.rawValue })
            if sortedAreaIDs.count == 1, let areaID = sortedAreaIDs.first {
                return .success(areaID)
            }
            if sortedAreaIDs.count > 1 {
                return .failure(.areaResolutionAmbiguousForAddNode)
            }
            return .failure(.focusedNodeNotFound)
        case .setNodeText(let nodeID, _, _):
            return CanvasAreaMembershipService.areaID(containing: nodeID, in: graph)
        case .upsertNodeAttachment(let nodeID, _, _, _):
            return CanvasAreaMembershipService.areaID(containing: nodeID, in: graph)
        case .focusNode(let nodeID):
            return CanvasAreaMembershipService.areaID(containing: nodeID, in: graph)
        case .focusArea(let areaID):
            if graph.areasByID[areaID] != nil {
                return .success(areaID)
            }
            return .failure(.areaNotFound(areaID))
        case .connectNodes(let fromNodeID, _):
            return CanvasAreaMembershipService.areaID(containing: fromNodeID, in: graph)
        case .deleteSelectedOrFocusedEdges(let focusedEdge, _):
            return CanvasAreaMembershipService.areaID(containing: focusedEdge.originNodeID, in: graph)
        case .cycleFocusedEdgeDirectionality(let focusedEdge, _):
            return CanvasAreaMembershipService.areaID(containing: focusedEdge.originNodeID, in: graph)
        case .addChildNode,
            .addSiblingNode,
            .duplicateSelectionAsSibling,
            .alignAllAreasVertically,
            .moveFocus,
            .moveFocusAcrossAreasToRoot,
            .extendSelection,
            .moveNode,
            .nudgeNode,
            .scaleSelectedNodes,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .deleteSelectedOrFocusedNodes,
            .copySelectionOrFocusedSubtree,
            .cutSelectionOrFocusedSubtree,
            .pasteClipboardAtFocusedNode,
            .toggleFocusedNodeMarkdownStyle,
            .convertFocusedAreaMode,
            .createArea,
            .assignNodesToArea:
            return CanvasAreaMembershipService.focusedAreaID(in: graph)
        }
    }

    private func normalize(
        command: CanvasCommand,
        in graph: CanvasGraph
    ) -> CanvasCommand {
        guard case .addChildNode = command else {
            return command
        }
        guard
            let focusedNodeID = graph.focusedNodeID,
            graph.nodesByID[focusedNodeID] != nil
        else {
            let sortedAreaIDs = graph.areasByID.keys.sorted(by: { $0.rawValue < $1.rawValue })
            guard sortedAreaIDs.count == 1, let areaID = sortedAreaIDs.first else {
                return command
            }
            switch CanvasAreaMembershipService.area(withID: areaID, in: graph) {
            case .success(let area):
                return area.editingMode == .diagram ? .addNode : command
            case .failure:
                return command
            }
        }

        switch CanvasAreaMembershipService.areaID(containing: focusedNodeID, in: graph) {
        case .success(let areaID):
            switch CanvasAreaMembershipService.area(withID: areaID, in: graph) {
            case .success(let area):
                return area.editingMode == .diagram ? .addNode : command
            case .failure:
                return command
            }
        case .failure:
            return command
        }
    }
}
