// Background: CRUD operations need explicit failure reasons for invariant violations.
// Responsibility: Represent domain-level graph editing errors.
/// Errors emitted when canvas graph invariants are broken.
public enum CanvasGraphError: Error, Equatable, Sendable {
    /// Node identifier is empty or malformed.
    case invalidNodeID
    /// Edge identifier is empty or malformed.
    case invalidEdgeID
    /// Node bounds are invalid (for example non-positive size).
    case invalidNodeBounds
    /// Attempted to create a node with an existing identifier.
    case nodeAlreadyExists(CanvasNodeID)
    /// Requested node does not exist in the graph.
    case nodeNotFound(CanvasNodeID)
    /// Attempted to create an edge with an existing identifier.
    case edgeAlreadyExists(CanvasEdgeID)
    /// Requested edge does not exist in the graph.
    case edgeNotFound(CanvasEdgeID)
    /// Edge endpoint references a node not present in the graph.
    case edgeEndpointNotFound(CanvasNodeID)
}
