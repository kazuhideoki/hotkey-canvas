public enum CanvasCommand: Equatable, Sendable {
    case addNode
    case addChildNode
    case addSiblingNode
    case moveFocus(CanvasFocusDirection)
    case focusNode(CanvasNodeID)
    case deleteFocusedNode
    case focusNode(CanvasNodeID)
    case setNodeText(nodeID: CanvasNodeID, text: String)
}

/// Direction used to move node focus on canvas.
public enum CanvasFocusDirection: Equatable, Sendable {
    case up
    case down
    case left
    case right
}
