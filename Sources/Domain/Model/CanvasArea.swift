// Background: Tree and diagram semantics are separated by area in one graph.
// Responsibility: Hold node membership and mode for one editable canvas area.
/// Immutable area aggregate for mode-specific editing boundaries.
public struct CanvasArea: Equatable, Sendable {
    /// Area identifier.
    public let id: CanvasAreaID
    /// Node identifiers that belong to this area.
    public let nodeIDs: Set<CanvasNodeID>
    /// Editing mode applied to nodes in this area.
    public let editingMode: CanvasEditingMode
    /// Edge shape style applied to edges in this area.
    public let edgeShapeStyle: CanvasAreaEdgeShapeStyle

    /// Creates an immutable area snapshot.
    /// - Parameters:
    ///   - id: Area identifier.
    ///   - nodeIDs: Member node identifiers.
    ///   - editingMode: Editing mode of the area.
    ///   - edgeShapeStyle: Edge shape style of the area.
    public init(
        id: CanvasAreaID,
        nodeIDs: Set<CanvasNodeID>,
        editingMode: CanvasEditingMode,
        edgeShapeStyle: CanvasAreaEdgeShapeStyle = .curved
    ) {
        self.id = id
        self.nodeIDs = nodeIDs
        self.editingMode = editingMode
        self.edgeShapeStyle = edgeShapeStyle
    }
}
