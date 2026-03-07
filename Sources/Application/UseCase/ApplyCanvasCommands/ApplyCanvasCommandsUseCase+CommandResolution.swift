import Domain

// Background: Command dispatch needs reusable area resolution and normalization helpers.
// Responsibility: Resolve execution area and normalized command variants before mutation.
extension ApplyCanvasCommandsUseCase {
    struct ResolvedCommandContext {
        let command: CanvasCommand
        let areaID: CanvasAreaID
        let area: CanvasArea
        let executionContext: KeymapExecutionContext
    }

    func resolveAreaID(
        for command: CanvasCommand,
        in graph: CanvasGraph
    ) -> Result<CanvasAreaID, CanvasAreaPolicyError> {
        switch command {
        case .addNode:
            return resolveAreaIDForAddNode(in: graph)
        case .setNodeText(let nodeID, _, _), .upsertNodeAttachment(let nodeID, _, _, _), .focusNode(let nodeID):
            return CanvasAreaMembershipService.areaID(containing: nodeID, in: graph)
        case .setEdgeLabel(let edgeID, _):
            return resolveAreaIDForSetEdgeLabel(edgeID: edgeID, in: graph)
        case .focusArea(let areaID):
            guard graph.areasByID[areaID] != nil else {
                return .failure(.areaNotFound(areaID))
            }
            return .success(areaID)
        case .connectNodes(let fromNodeID, _):
            return CanvasAreaMembershipService.areaID(containing: fromNodeID, in: graph)
        case .deleteSelectedOrFocusedEdges(let focusedEdge, _),
            .cycleFocusedEdgeDirectionality(let focusedEdge, _):
            return CanvasAreaMembershipService.areaID(containing: focusedEdge.originNodeID, in: graph)
        default:
            return CanvasAreaMembershipService.focusedAreaID(in: graph)
        }
    }

    func normalize(
        command: CanvasCommand,
        in graph: CanvasGraph
    ) -> CanvasCommand {
        guard case .addChildNode = command else {
            return command
        }
        guard let diagramArea = normalizedAddChildDiagramArea(in: graph) else {
            return command
        }
        return diagramArea.editingMode == .diagram ? .addNode : command
    }

    private func resolveAreaIDForAddNode(in graph: CanvasGraph) -> Result<CanvasAreaID, CanvasAreaPolicyError> {
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
    }

    private func resolveAreaIDForSetEdgeLabel(
        edgeID: CanvasEdgeID,
        in graph: CanvasGraph
    ) -> Result<CanvasAreaID, CanvasAreaPolicyError> {
        guard let edge = graph.edgesByID[edgeID] else {
            return CanvasAreaMembershipService.focusedAreaID(in: graph)
        }
        return CanvasAreaMembershipService.areaID(containing: edge.fromNodeID, in: graph)
    }

    private func normalizedAddChildDiagramArea(in graph: CanvasGraph) -> CanvasArea? {
        if let focusedNodeID = graph.focusedNodeID, graph.nodesByID[focusedNodeID] != nil {
            return areaForNormalizedAddChild(nodeID: focusedNodeID, in: graph)
        }
        let sortedAreaIDs = graph.areasByID.keys.sorted(by: { $0.rawValue < $1.rawValue })
        guard sortedAreaIDs.count == 1, let areaID = sortedAreaIDs.first else {
            return nil
        }
        switch CanvasAreaMembershipService.area(withID: areaID, in: graph) {
        case .success(let area):
            return area
        case .failure:
            return nil
        }
    }

    private func areaForNormalizedAddChild(
        nodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> CanvasArea? {
        switch CanvasAreaMembershipService.areaID(containing: nodeID, in: graph) {
        case .success(let areaID):
            switch CanvasAreaMembershipService.area(withID: areaID, in: graph) {
            case .success(let area):
                return area
            case .failure:
                return nil
            }
        case .failure:
            return nil
        }
    }
}
