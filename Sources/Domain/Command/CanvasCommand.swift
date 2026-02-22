public enum CanvasCommand: Equatable, Sendable {
    case addNode
    case addChildNode
    case addSiblingNode(position: CanvasSiblingNodePosition)
    case moveFocus(CanvasFocusDirection)
    case moveNode(CanvasNodeMoveDirection)
    case toggleFoldFocusedSubtree
    case centerFocusedNode
    case deleteFocusedNode
    case copyFocusedSubtree
    case cutFocusedSubtree
    case pasteSubtreeAsChild
    case setNodeText(nodeID: CanvasNodeID, text: String, nodeHeight: Double)
    case toggleFocusedNodeMarkdownStyle
    case convertFocusedAreaMode(to: CanvasEditingMode)
    case createArea(id: CanvasAreaID, mode: CanvasEditingMode, nodeIDs: Set<CanvasNodeID>)
    case assignNodesToArea(nodeIDs: Set<CanvasNodeID>, areaID: CanvasAreaID)
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

/// Direction used to move focused node order or hierarchy.
public enum CanvasNodeMoveDirection: Equatable, Sendable {
    case up
    case down
    case left
    case right
}
