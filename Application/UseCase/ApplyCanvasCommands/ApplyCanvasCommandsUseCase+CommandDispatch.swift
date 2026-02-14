import Domain

// Background: Canvas editing supports multiple command kinds behind a single apply entry point.
// Responsibility: Dispatch each command to the corresponding operation handler.
extension ApplyCanvasCommandsUseCase {
    func apply(command: CanvasCommand, to graph: CanvasGraph) throws -> CanvasGraph {
        switch command {
        case .addNode:
            return try addNode(in: graph)
        case .addChildNode:
            return try addChildNode(in: graph, requiresTopLevelParent: false)
        case .addSiblingNode:
            return try addSiblingNode(in: graph)
        case .moveFocus(let direction):
            return moveFocus(in: graph, direction: direction)
        case .deleteFocusedNode:
            return try deleteFocusedNode(in: graph)
        case .setNodeText(let nodeID, let text):
            return try setNodeText(in: graph, nodeID: nodeID, text: text)
        }
    }
}
