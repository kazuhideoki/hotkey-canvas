public enum CanvasCommand: Equatable, Sendable {
    case addNode
    case addChildNode
    case addSiblingNode(position: CanvasSiblingNodePosition)
    case duplicateSelectionAsSibling
    case connectNodes(fromNodeID: CanvasNodeID, toNodeID: CanvasNodeID)
    case alignAllAreasVertically
    case moveFocus(CanvasFocusDirection)
    case moveFocusAcrossAreasToRoot(CanvasFocusDirection)
    case focusNode(CanvasNodeID)
    case focusArea(CanvasAreaID)
    case extendSelection(CanvasFocusDirection)
    case moveArea(CanvasFocusDirection)
    case moveNode(CanvasNodeMoveDirection)
    case nudgeNode(CanvasNodeMoveDirection)
    case scaleSelectedNodes(CanvasNodeScaleDirection)
    case toggleFoldFocusedSubtree
    case centerFocusedNode
    case deleteSelectedOrFocusedNodes
    case deleteSelectedOrFocusedEdges(
        focusedEdge: CanvasEdgeFocus,
        selectedEdgeIDs: Set<CanvasEdgeID>
    )
    case cycleFocusedEdgeDirectionality(
        focusedEdge: CanvasEdgeFocus,
        selectedEdgeIDs: Set<CanvasEdgeID>
    )
    case setEdgeLabel(edgeID: CanvasEdgeID, label: String)
    case copySelectionOrFocusedSubtree
    case cutSelectionOrFocusedSubtree
    case pasteClipboardAtFocusedNode
    case setNodeText(nodeID: CanvasNodeID, text: String, nodeHeight: Double)
    case upsertNodeAttachment(nodeID: CanvasNodeID, attachment: CanvasAttachment, nodeWidth: Double, nodeHeight: Double)
    case toggleFocusedNodeMarkdownStyle
    case toggleFocusedAreaEdgeShapeStyle
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

/// Direction used to scale selected nodes.
public enum CanvasNodeScaleDirection: Equatable, Sendable {
    case up
    case down
}
