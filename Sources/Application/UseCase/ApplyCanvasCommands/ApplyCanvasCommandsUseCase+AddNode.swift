import Domain
import Foundation

// Background: Adding a node is one of the baseline editing actions in the canvas workflow.
// Responsibility: Insert a new text node at an available position and move focus to it.
extension ApplyCanvasCommandsUseCase {
    /// Creates one top-level text node and marks only area layout as required for follow-up stages.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Mutation result focused on the newly created node.
    /// - Throws: Propagates node creation failure from CRUD service.
    func addNode(in graph: CanvasGraph, areaID: CanvasAreaID) throws -> CanvasMutationResult {
        let area = try CanvasAreaMembershipService.area(withID: areaID, in: graph).get()
        let bounds: CanvasBounds
        switch area.editingMode {
        case .tree:
            bounds = makeAvailableNewNodeBounds(in: graph)
        case .diagram:
            let diagramNodeSideLength = CanvasDefaultNodeDistance.diagramNodeSide
            let placementCollisionNodeIDs =
                area.nodeIDs.isEmpty
                ? Set(graph.nodesByID.keys)
                : area.nodeIDs
            bounds = makeAvailableDiagramNewNodeBounds(
                in: graph,
                avoiding: placementCollisionNodeIDs,
                width: diagramNodeSideLength,
                height: diagramNodeSideLength,
                verticalSpacing: CanvasDefaultNodeDistance.vertical(for: .diagram)
            )
        }
        let node = makeTextNode(bounds: bounds)
        var graphAfterMutation = try CanvasGraphCRUDService.createNode(node, in: graph).get()
        graphAfterMutation = try CanvasAreaMembershipService.assign(
            nodeIDs: Set([node.id]),
            to: areaID,
            in: graphAfterMutation
        ).get()
        if area.editingMode == .diagram,
            let focusedNodeID = graph.focusedNodeID,
            graph.nodesByID[focusedNodeID] != nil,
            isFocusedNodeInArea(graph: graph, focusedNodeID: focusedNodeID, areaID: areaID)
        {
            graphAfterMutation = try CanvasGraphCRUDService.createEdge(
                CanvasEdge(
                    id: CanvasEdgeID(rawValue: "edge-\(UUID().uuidString.lowercased())"),
                    fromNodeID: focusedNodeID,
                    toNodeID: node.id,
                    relationType: .normal
                ),
                in: graphAfterMutation
            ).get()
        }
        let nextGraph = CanvasGraph(
            nodesByID: graphAfterMutation.nodesByID,
            edgesByID: graphAfterMutation.edgesByID,
            focusedNodeID: node.id,
            selectedNodeIDs: [node.id],
            collapsedRootNodeIDs: graphAfterMutation.collapsedRootNodeIDs,
            areasByID: graphAfterMutation.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: area.editingMode == .tree,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: node.id
        )
    }

    private func isFocusedNodeInArea(
        graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        areaID: CanvasAreaID
    ) -> Bool {
        switch CanvasAreaMembershipService.areaID(containing: focusedNodeID, in: graph) {
        case .success(let focusedAreaID):
            return focusedAreaID == areaID
        case .failure:
            return false
        }
    }
}
