// Background: Canvas interactions need a stable way to represent whether focus targets a node or an edge.
// Responsibility: Provide strongly typed focus payloads for node/edge targeting.
/// Focus payload for edge-target operations.
public struct CanvasEdgeFocus: Equatable, Sendable {
    /// Focused edge identifier.
    public let edgeID: CanvasEdgeID
    /// Origin node identifier used to restore node target when exiting edge mode.
    public let originNodeID: CanvasNodeID

    /// Creates an edge focus payload.
    /// - Parameters:
    ///   - edgeID: Focused edge identifier.
    ///   - originNodeID: Origin node identifier.
    public init(edgeID: CanvasEdgeID, originNodeID: CanvasNodeID) {
        self.edgeID = edgeID
        self.originNodeID = originNodeID
    }
}

/// Target kind currently focused on canvas.
public enum CanvasFocusedElement: Equatable, Sendable {
    case node(CanvasNodeID)
    case edge(CanvasEdgeFocus)
}
