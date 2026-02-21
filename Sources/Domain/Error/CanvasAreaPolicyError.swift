// Background: Area-mode routing requires explicit reasons when area contracts fail.
// Responsibility: Represent domain-level errors for area membership and mode policies.
/// Errors emitted when area membership or mode policy contracts are violated.
public enum CanvasAreaPolicyError: Error, Equatable, Sendable {
    /// Graph has nodes but area metadata is missing.
    case areaDataMissing
    /// Focused node identifier is missing or stale.
    case focusedNodeNotFound
    /// Focused node is not assigned to any area.
    case focusedNodeNotAssignedToArea(CanvasNodeID)
    /// One node is assigned to multiple areas.
    case nodeAssignedToMultipleAreas(CanvasNodeID)
    /// One node is not assigned to any area.
    case nodeWithoutArea(CanvasNodeID)
    /// Area references a node that does not exist in graph nodes.
    case areaContainsMissingNode(CanvasAreaID, CanvasNodeID)
    /// Requested area was not found.
    case areaNotFound(CanvasAreaID)
    /// Attempted to create an area with an existing identifier.
    case areaAlreadyExists(CanvasAreaID)
    /// Command is not supported by the resolved area editing mode.
    case unsupportedCommandInMode(mode: CanvasEditingMode, command: CanvasCommand)
    /// Cross-area edge is prohibited by current policy.
    case crossAreaEdgeForbidden(CanvasEdgeID)
}
