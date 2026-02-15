// Background: Hierarchy-aware layout needs a stable unit that groups connected nodes.
// Responsibility: Represent one immutable connected area and its current outer bounds.
/// Immutable connected-node area used for collision resolution.
public struct CanvasNodeArea: Equatable, Sendable {
    /// Deterministic representative node identifier for the area.
    public let id: CanvasNodeID
    /// Node identifiers included in this area.
    public let nodeIDs: Set<CanvasNodeID>
    /// Axis-aligned bounds that enclose all nodes in this area.
    public let bounds: CanvasRect

    /// Creates a connected area.
    /// - Parameters:
    ///   - id: Deterministic representative node identifier.
    ///   - nodeIDs: Node identifiers included in this area.
    ///   - bounds: Axis-aligned area bounds.
    public init(id: CanvasNodeID, nodeIDs: Set<CanvasNodeID>, bounds: CanvasRect) {
        self.id = id
        self.nodeIDs = nodeIDs
        self.bounds = bounds
    }
}
