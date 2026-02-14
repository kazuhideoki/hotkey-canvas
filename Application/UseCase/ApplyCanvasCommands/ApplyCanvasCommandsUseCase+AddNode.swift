import Domain

// Background: Adding a node is one of the baseline editing actions in the canvas workflow.
// Responsibility: Insert a new text node at an available position and move focus to it.
extension ApplyCanvasCommandsUseCase {
    func addNode(in graph: CanvasGraph) throws -> CanvasGraph {
        let node = makeTextNode(bounds: makeAvailableNewNodeBounds(in: graph))
        let graphWithNode = try CanvasGraphCRUDService.createNode(node, in: graph)
        return CanvasGraph(
            nodesByID: graphWithNode.nodesByID,
            edgesByID: graphWithNode.edgesByID,
            focusedNodeID: node.id
        )
    }
}
