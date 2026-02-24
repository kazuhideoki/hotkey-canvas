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
        guard isCommand(normalizedCommand, supportedIn: resolvedArea.editingMode) else {
            throw CanvasAreaPolicyError.unsupportedCommandInMode(
                mode: resolvedArea.editingMode,
                command: normalizedCommand
            )
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
        switch command {
        case .addNode, .addChildNode, .addSiblingNode, .duplicateSelectionAsSibling, .connectNodes:
            return try applyNodeStructureCommand(
                command: command,
                to: graph,
                resolvedAreaID: resolvedAreaID
            )
        case .alignParentNodesVertically:
            return alignParentNodesVertically(in: graph, areaID: resolvedAreaID)
        case .moveFocus(let direction):
            return moveFocus(in: graph, direction: direction)
        case .focusNode(let nodeID):
            return focusNode(in: graph, nodeID: nodeID)
        case .extendSelection(let direction):
            return extendSelection(in: graph, direction: direction)
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
        case .deleteFocusedNode:
            return try deleteFocusedNode(
                in: graph,
                areaID: resolvedAreaID,
                areaMode: resolvedAreaMode
            )
        case .copyFocusedSubtree:
            return copyFocusedSubtree(in: graph)
        case .cutFocusedSubtree:
            return try cutFocusedSubtree(in: graph)
        case .pasteSubtreeAsChild:
            return try pasteSubtreeAsChild(in: graph)
        case .setNodeText, .upsertNodeAttachment, .toggleFocusedNodeMarkdownStyle:
            return try applyNodeContentCommand(command: command, to: graph)
        case .convertFocusedAreaMode, .createArea, .assignNodesToArea:
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
        case .alignParentNodesVertically,
            .moveFocus,
            .focusNode,
            .extendSelection,
            .moveNode,
            .nudgeNode,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .deleteFocusedNode,
            .copyFocusedSubtree,
            .cutFocusedSubtree,
            .pasteSubtreeAsChild,
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
        case .upsertNodeAttachment(let nodeID, let attachment, let nodeHeight):
            return try upsertNodeAttachment(
                in: graph,
                nodeID: nodeID,
                attachment: attachment,
                nodeHeight: nodeHeight
            )
        case .toggleFocusedNodeMarkdownStyle:
            return try toggleFocusedNodeMarkdownStyle(in: graph)
        case .addNode,
            .addChildNode,
            .addSiblingNode,
            .duplicateSelectionAsSibling,
            .connectNodes,
            .alignParentNodesVertically,
            .moveFocus,
            .focusNode,
            .extendSelection,
            .moveNode,
            .nudgeNode,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .deleteFocusedNode,
            .copyFocusedSubtree,
            .cutFocusedSubtree,
            .pasteSubtreeAsChild,
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
            .alignParentNodesVertically,
            .moveFocus,
            .focusNode,
            .extendSelection,
            .moveNode,
            .nudgeNode,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .deleteFocusedNode,
            .copyFocusedSubtree,
            .cutFocusedSubtree,
            .pasteSubtreeAsChild,
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

    private func isCommand(_ command: CanvasCommand, supportedIn mode: CanvasEditingMode) -> Bool {
        switch mode {
        case .tree:
            return TreeAreaPolicyService.supports(command)
        case .diagram:
            return DiagramAreaPolicyService.supports(command)
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
        case .upsertNodeAttachment(let nodeID, _, _):
            return CanvasAreaMembershipService.areaID(containing: nodeID, in: graph)
        case .focusNode(let nodeID):
            return CanvasAreaMembershipService.areaID(containing: nodeID, in: graph)
        case .connectNodes(let fromNodeID, _):
            return CanvasAreaMembershipService.areaID(containing: fromNodeID, in: graph)
        case .addChildNode,
            .addSiblingNode,
            .duplicateSelectionAsSibling,
            .alignParentNodesVertically,
            .moveFocus,
            .extendSelection,
            .moveNode,
            .nudgeNode,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .deleteFocusedNode,
            .copyFocusedSubtree,
            .cutFocusedSubtree,
            .pasteSubtreeAsChild,
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
