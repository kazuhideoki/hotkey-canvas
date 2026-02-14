import Domain

// Background: Explicit focus commands allow adapters to request node selection directly.
// Responsibility: Set focus only when the requested node exists and differs from current focus.
extension ApplyCanvasCommandsUseCase {
    func focusNode(in graph: CanvasGraph, nodeID: CanvasNodeID) -> CanvasGraph {
        guard graph.nodesByID[nodeID] != nil else {
            return graph
        }
        guard graph.focusedNodeID != nodeID else {
            return graph
        }

        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nodeID
        )
    }
}
