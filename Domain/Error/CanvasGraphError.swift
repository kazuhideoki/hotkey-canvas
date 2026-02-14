public enum CanvasGraphError: Error, Equatable, Sendable {
    case invalidNodeID
    case invalidEdgeID
    case invalidNodeBounds
    case nodeAlreadyExists(CanvasNodeID)
    case nodeNotFound(CanvasNodeID)
    case edgeAlreadyExists(CanvasEdgeID)
    case edgeNotFound(CanvasEdgeID)
    case edgeEndpointNotFound(CanvasNodeID)
}
