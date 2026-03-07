import Domain

// Background: Command dispatch needs one place to normalize commands and resolve area routing before mutation.
// Responsibility: Normalize commands and map them to the effective area for dispatch.
extension ApplyCanvasCommandsUseCase {
    func resolveAreaID(
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
        case .setEdgeLabel(let edgeID, _):
            guard let edge = graph.edgesByID[edgeID] else {
                return CanvasAreaMembershipService.focusedAreaID(in: graph)
            }
            return CanvasAreaMembershipService.areaID(containing: edge.fromNodeID, in: graph)
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
            .moveArea,
            .moveNode,
            .nudgeNode,
            .alignSelectedNodes,
            .scaleSelectedNodes,
            .toggleFoldFocusedSubtree,
            .centerFocusedNode,
            .deleteSelectedOrFocusedNodes,
            .copySelectionOrFocusedSubtree,
            .cutSelectionOrFocusedSubtree,
            .pasteClipboardAtFocusedNode,
            .toggleFocusedNodeMarkdownStyle,
            .toggleFocusedAreaEdgeShapeStyle,
            .convertFocusedAreaMode,
            .createArea,
            .assignNodesToArea:
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
        guard
            let focusedNodeID = graph.focusedNodeID,
            graph.nodesByID[focusedNodeID] != nil
        else {
            return normalizeAddChildWithoutFocus(in: graph, fallback: command)
        }

        switch CanvasAreaMembershipService.areaID(containing: focusedNodeID, in: graph) {
        case .success(let areaID):
            return normalizedAddChildCommand(
                in: graph,
                areaID: areaID,
                fallback: command
            )
        case .failure:
            return command
        }
    }

    private func normalizeAddChildWithoutFocus(
        in graph: CanvasGraph,
        fallback command: CanvasCommand
    ) -> CanvasCommand {
        let sortedAreaIDs = graph.areasByID.keys.sorted(by: { $0.rawValue < $1.rawValue })
        guard sortedAreaIDs.count == 1, let areaID = sortedAreaIDs.first else {
            return command
        }
        return normalizedAddChildCommand(in: graph, areaID: areaID, fallback: command)
    }

    private func normalizedAddChildCommand(
        in graph: CanvasGraph,
        areaID: CanvasAreaID,
        fallback command: CanvasCommand
    ) -> CanvasCommand {
        switch CanvasAreaMembershipService.area(withID: areaID, in: graph) {
        case .success(let area):
            return area.editingMode == .diagram ? .addNode : command
        case .failure:
            return command
        }
    }
}
