// Background: Graph relationships are represented as first-class immutable values.
// Responsibility: Describe one directed relation between two nodes.
/// Immutable edge connecting two nodes in a canvas graph.
public struct CanvasEdge: Equatable, Sendable {
    /// Unique edge identifier.
    public let id: CanvasEdgeID
    /// Source node identifier.
    public let fromNodeID: CanvasNodeID
    /// Destination node identifier.
    public let toNodeID: CanvasNodeID
    /// Semantic relation kind.
    public let relationType: CanvasEdgeRelationType
    /// Optional user-visible label.
    public let label: String?
    /// Additional key-value metadata.
    public let metadata: [String: String]

    /// Creates a graph edge value.
    /// - Parameters:
    ///   - id: Unique edge identifier.
    ///   - fromNodeID: Source node identifier.
    ///   - toNodeID: Destination node identifier.
    ///   - relationType: Semantic relation kind.
    ///   - label: Optional edge label.
    ///   - metadata: Additional metadata attributes.
    public init(
        id: CanvasEdgeID,
        fromNodeID: CanvasNodeID,
        toNodeID: CanvasNodeID,
        relationType: CanvasEdgeRelationType = .normal,
        label: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.fromNodeID = fromNodeID
        self.toNodeID = toNodeID
        self.relationType = relationType
        self.label = label
        self.metadata = metadata
    }
}
