public enum CanvasCommand: Equatable, Sendable {
    case addNode
    case addChildNode
    case addSiblingNode(position: CanvasSiblingNodePosition)
    case moveFocus(CanvasFocusDirection)
    case deleteFocusedNode
    case setNodeText(nodeID: CanvasNodeID, text: String, nodeHeight: Double)
}

/// Position used when adding a sibling node relative to focused node.
public enum CanvasSiblingNodePosition: Equatable, Sendable {
    case above
    case below
}

/// Direction used to move node focus on canvas.
public enum CanvasFocusDirection: Equatable, Sendable {
    case up
    case down
    case left
    case right
}
