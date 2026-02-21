import Domain

// Background: Canvas editing supports multiple command kinds behind a single apply entry point.
// Responsibility: Dispatch each command to the corresponding operation handler.
extension ApplyCanvasCommandsUseCase {
    /// Dispatches one command to its mutation handler and returns stage effects with the result graph.
    func applyMutation(command: CanvasCommand, to graph: CanvasGraph) throws -> CanvasMutationResult {
        try CanvasAreaMembershipService.validate(in: graph).get()
        let resolvedAreaID = try resolveAreaID(for: command, in: graph).get()
        let resolvedArea = try CanvasAreaMembershipService.area(withID: resolvedAreaID, in: graph).get()
        guard isCommand(command, supportedIn: resolvedArea.editingMode) else {
            throw CanvasAreaPolicyError.unsupportedCommandInMode(mode: resolvedArea.editingMode, command: command)
        }

        switch command {
        case .addNode:
            return try addNode(in: graph, areaID: resolvedAreaID)
        case .addChildNode:
            return try addChildNode(in: graph, requiresTopLevelParent: false)
        case .addSiblingNode(let position):
            return try addSiblingNode(in: graph, position: position)
        case .moveFocus(let direction):
            return moveFocus(in: graph, direction: direction)
        case .moveNode(let direction):
            return try moveNode(in: graph, direction: direction)
        case .toggleFoldFocusedSubtree:
            return toggleFoldFocusedSubtree(in: graph)
        case .centerFocusedNode:
            return noOpMutationResult(for: graph)
        case .deleteFocusedNode:
            return try deleteFocusedNode(in: graph)
        case .setNodeText(let nodeID, let text, let nodeHeight):
            return try setNodeText(in: graph, nodeID: nodeID, text: text, nodeHeight: nodeHeight)
        case .createArea(let id, let mode, let nodeIDs):
            let graphAfterMutation = try CanvasAreaMembershipService.createArea(
                id: id,
                mode: mode,
                nodeIDs: nodeIDs,
                in: graph
            ).get()
            return CanvasMutationResult(
                graphBeforeMutation: graph,
                graphAfterMutation: graphAfterMutation,
                effects: CanvasMutationEffects(
                    didMutateGraph: graphAfterMutation != graph,
                    needsTreeLayout: false,
                    needsAreaLayout: false,
                    needsFocusNormalization: false
                )
            )
        case .assignNodesToArea(let nodeIDs, let areaID):
            let graphAfterMutation = try CanvasAreaMembershipService.assign(
                nodeIDs: nodeIDs,
                to: areaID,
                in: graph
            ).get()
            return CanvasMutationResult(
                graphBeforeMutation: graph,
                graphAfterMutation: graphAfterMutation,
                effects: CanvasMutationEffects(
                    didMutateGraph: graphAfterMutation != graph,
                    needsTreeLayout: false,
                    needsAreaLayout: false,
                    needsFocusNormalization: false
                )
            )
        }
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
            return .failure(.focusedNodeNotFound)
        case .setNodeText(let nodeID, _, _):
            return CanvasAreaMembershipService.areaID(containing: nodeID, in: graph)
        case .addChildNode,
            .addSiblingNode,
            .moveFocus,
            .moveNode,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .deleteFocusedNode,
            .createArea,
            .assignNodesToArea:
            return CanvasAreaMembershipService.focusedAreaID(in: graph)
        }
    }
}
