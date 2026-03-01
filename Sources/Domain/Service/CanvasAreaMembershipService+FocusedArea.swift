// Background: Focus can target both node and area, but commands still need one resolved area identifier.
// Responsibility: Resolve focused area identifier from focused element and focused node contracts.
extension CanvasAreaMembershipService {
    /// Resolves focused node area identifier.
    /// - Parameter graph: Graph snapshot.
    /// - Returns: Area identifier that owns the current focused node.
    public static func focusedAreaID(in graph: CanvasGraph) -> Result<CanvasAreaID, CanvasAreaPolicyError> {
        if case .area(let areaID) = graph.focusedElement {
            guard graph.areasByID[areaID] != nil else {
                return .failure(.areaNotFound(areaID))
            }
            return .success(areaID)
        }
        guard let focusedNodeID = graph.focusedNodeID, graph.nodesByID[focusedNodeID] != nil else {
            return .failure(.focusedNodeNotFound)
        }
        return areaID(containing: focusedNodeID, in: graph).mapError { error in
            switch error {
            case .nodeWithoutArea:
                return .focusedNodeNotAssignedToArea(focusedNodeID)
            default:
                return error
            }
        }
    }
}
