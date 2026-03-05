// Background: Graph state is shared across use cases as immutable snapshots.
// Responsibility: Hold all nodes and edges keyed by their identifiers.
/// Immutable aggregate root for nodes and edges.
public struct CanvasGraph: Equatable, Sendable {
    /// Node collection indexed by node identifier.
    public let nodesByID: [CanvasNodeID: CanvasNode]
    /// Edge collection indexed by edge identifier.
    public let edgesByID: [CanvasEdgeID: CanvasEdge]
    /// Currently focused node identifier.
    public let focusedNodeID: CanvasNodeID?
    /// Currently focused element target.
    public let focusedElement: CanvasFocusedElement?
    /// Selected node identifiers used for multi-node operations.
    public let selectedNodeIDs: Set<CanvasNodeID>
    /// Selected edge identifiers used for edge-target operations.
    public let selectedEdgeIDs: Set<CanvasEdgeID>
    /// Root node identifiers whose descendant subtrees are folded in UI.
    public let collapsedRootNodeIDs: Set<CanvasNodeID>
    /// Area collection indexed by area identifier.
    public let areasByID: [CanvasAreaID: CanvasArea]

    /// Creates an immutable graph snapshot.
    /// - Parameters:
    ///   - nodesByID: Node dictionary keyed by identifier.
    ///   - edgesByID: Edge dictionary keyed by identifier.
    ///   - focusedNodeID: Currently focused node identifier.
    ///   - focusedElement: Currently focused element target.
    ///   - selectedNodeIDs: Selected node identifiers.
    ///   - selectedEdgeIDs: Selected edge identifiers.
    ///   - collapsedRootNodeIDs: Folded subtree root identifiers.
    ///   - areasByID: Area dictionary keyed by identifier.
    public init(
        nodesByID: [CanvasNodeID: CanvasNode] = [:],
        edgesByID: [CanvasEdgeID: CanvasEdge] = [:],
        focusedNodeID: CanvasNodeID? = nil,
        focusedElement: CanvasFocusedElement? = nil,
        selectedNodeIDs: Set<CanvasNodeID> = [],
        selectedEdgeIDs: Set<CanvasEdgeID> = [],
        collapsedRootNodeIDs: Set<CanvasNodeID> = [],
        areasByID: [CanvasAreaID: CanvasArea] = [:]
    ) {
        self.nodesByID = nodesByID
        self.edgesByID = edgesByID
        self.focusedNodeID = focusedNodeID
        self.focusedElement = focusedElement ?? focusedNodeID.map { .node($0) }
        self.selectedNodeIDs = selectedNodeIDs
        self.selectedEdgeIDs = selectedEdgeIDs
        self.collapsedRootNodeIDs = collapsedRootNodeIDs
        self.areasByID = areasByID
    }

    /// Empty graph constant used as an initial state.
    public static let empty = CanvasGraph(
        areasByID: [
            .defaultTree: CanvasArea(
                id: .defaultTree,
                nodeIDs: [],
                editingMode: .tree,
                edgeShapeStyle: .curved
            )
        ]
    )
}
