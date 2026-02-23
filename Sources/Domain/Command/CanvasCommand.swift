public enum CanvasCommand: Equatable, Sendable {
    case addNode
    case addChildNode
    case addSiblingNode(position: CanvasSiblingNodePosition)
    case duplicateSelectionAsSibling
    case connectNodes(fromNodeID: CanvasNodeID, toNodeID: CanvasNodeID)
    case alignParentNodesVertically
    case moveFocus(CanvasFocusDirection)
    case extendSelection(CanvasFocusDirection)
    case moveNode(CanvasNodeMoveDirection)
    case nudgeNode(CanvasNodeMoveDirection)
    case toggleFoldFocusedSubtree
    case centerFocusedNode
    case deleteFocusedNode
    case copyFocusedSubtree
    case cutFocusedSubtree
    case pasteSubtreeAsChild
    case setNodeText(nodeID: CanvasNodeID, text: String, nodeHeight: Double)
    case upsertNodeAttachment(nodeID: CanvasNodeID, attachment: CanvasAttachment, nodeHeight: Double)
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
    case upLeft
    case upRight
    case downLeft
    case downRight
}
