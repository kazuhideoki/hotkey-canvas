public enum CanvasCommand: Equatable, Sendable {
    case addNode
    case addChildNode
    case addChildNodeFromTopLevelParent
    case moveFocus(CanvasFocusDirection)
    case focusNode(CanvasNodeID)
    case deleteFocusedNode
}

/// Direction used to move node focus on canvas.
public enum CanvasFocusDirection: Equatable, Sendable {
    case up
    case down
    case left
    case right
}
