// Background: Area membership and mode routing require deterministic domain-level checks.
// Responsibility: Validate and mutate area membership data without framework dependencies.
/// Pure domain service for canvas area membership validation and updates.
public enum CanvasAreaMembershipService {
    /// Validates that every node belongs to exactly one area and area nodes exist.
    /// - Parameter graph: Graph snapshot to validate.
    /// - Returns: `.success(())` when valid, otherwise area policy error.
    public static func validate(in graph: CanvasGraph) -> Result<Void, CanvasAreaPolicyError> {
        if !graph.nodesByID.isEmpty && graph.areasByID.isEmpty {
            return .failure(.areaDataMissing)
        }

        var membershipCountByNodeID: [CanvasNodeID: Int] = [:]

        for areaID in graph.areasByID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let area = graph.areasByID[areaID] else {
                continue
            }
            for nodeID in area.nodeIDs {
                guard graph.nodesByID[nodeID] != nil else {
                    return .failure(.areaContainsMissingNode(area.id, nodeID))
                }
                membershipCountByNodeID[nodeID, default: 0] += 1
            }
        }

        for nodeID in graph.nodesByID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            let membershipCount = membershipCountByNodeID[nodeID] ?? 0
            if membershipCount == 0 {
                return .failure(.nodeWithoutArea(nodeID))
            }
            if membershipCount > 1 {
                return .failure(.nodeAssignedToMultipleAreas(nodeID))
            }
        }

        return .success(())
    }

    /// Resolves area identifier that contains the given node.
    /// - Parameters:
    ///   - nodeID: Target node identifier.
    ///   - graph: Graph snapshot.
    /// - Returns: Area identifier containing the node.
    public static func areaID(containing nodeID: CanvasNodeID, in graph: CanvasGraph) -> Result<
        CanvasAreaID, CanvasAreaPolicyError
    > {
        let matchedAreaIDs = graph.areasByID.values
            .filter { $0.nodeIDs.contains(nodeID) }
            .map(\.id)
            .sorted(by: { $0.rawValue < $1.rawValue })

        if matchedAreaIDs.isEmpty {
            return .failure(.nodeWithoutArea(nodeID))
        }
        if matchedAreaIDs.count > 1 {
            return .failure(.nodeAssignedToMultipleAreas(nodeID))
        }
        guard let areaID = matchedAreaIDs.first else {
            return .failure(.nodeWithoutArea(nodeID))
        }
        return .success(areaID)
    }

    /// Resolves focused node area identifier.
    /// - Parameter graph: Graph snapshot.
    /// - Returns: Area identifier that owns the current focused node.
    public static func focusedAreaID(in graph: CanvasGraph) -> Result<CanvasAreaID, CanvasAreaPolicyError> {
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

    /// Resolves area by identifier.
    /// - Parameters:
    ///   - areaID: Area identifier.
    ///   - graph: Graph snapshot.
    /// - Returns: Area model.
    public static func area(withID areaID: CanvasAreaID, in graph: CanvasGraph) -> Result<
        CanvasArea, CanvasAreaPolicyError
    > {
        guard let area = graph.areasByID[areaID] else {
            return .failure(.areaNotFound(areaID))
        }
        return .success(area)
    }

    /// Creates one new area.
    /// - Parameters:
    ///   - id: New area identifier.
    ///   - mode: Editing mode.
    ///   - nodeIDs: Initial member node identifiers.
    ///   - graph: Source graph.
    /// - Returns: Graph containing the created area.
    public static func createArea(
        id: CanvasAreaID,
        mode: CanvasEditingMode,
        nodeIDs: Set<CanvasNodeID>,
        in graph: CanvasGraph
    ) -> Result<CanvasGraph, CanvasAreaPolicyError> {
        guard graph.areasByID[id] == nil else {
            return .failure(.areaAlreadyExists(id))
        }

        for nodeID in nodeIDs {
            guard graph.nodesByID[nodeID] != nil else {
                return .failure(.areaContainsMissingNode(id, nodeID))
            }
        }

        var nextAreasByID = graph.areasByID
        for currentAreaID in nextAreasByID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let currentArea = nextAreasByID[currentAreaID] else {
                continue
            }
            nextAreasByID[currentAreaID] = CanvasArea(
                id: currentArea.id,
                nodeIDs: currentArea.nodeIDs.subtracting(nodeIDs),
                editingMode: currentArea.editingMode
            )
        }
        nextAreasByID[id] = CanvasArea(id: id, nodeIDs: nodeIDs, editingMode: mode)
        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: nextAreasByID
        )
        switch validateNoCrossAreaEdges(in: nextGraph) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        switch validate(in: nextGraph) {
        case .success:
            return .success(nextGraph)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Reassigns nodes to one target area.
    /// - Parameters:
    ///   - nodeIDs: Nodes to move.
    ///   - areaID: Destination area identifier.
    ///   - graph: Source graph.
    /// - Returns: Graph with updated area memberships.
    public static func assign(
        nodeIDs: Set<CanvasNodeID>,
        to areaID: CanvasAreaID,
        in graph: CanvasGraph
    ) -> Result<CanvasGraph, CanvasAreaPolicyError> {
        guard graph.areasByID[areaID] != nil else {
            return .failure(.areaNotFound(areaID))
        }
        for nodeID in nodeIDs {
            guard graph.nodesByID[nodeID] != nil else {
                return .failure(.areaContainsMissingNode(areaID, nodeID))
            }
        }

        var nextAreasByID = graph.areasByID
        for currentAreaID in nextAreasByID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let currentArea = nextAreasByID[currentAreaID] else {
                continue
            }
            let remainingNodeIDs = currentArea.nodeIDs.subtracting(nodeIDs)
            nextAreasByID[currentAreaID] = CanvasArea(
                id: currentArea.id,
                nodeIDs: remainingNodeIDs,
                editingMode: currentArea.editingMode
            )
        }

        guard let destination = nextAreasByID[areaID] else {
            return .failure(.areaNotFound(areaID))
        }
        nextAreasByID[areaID] = CanvasArea(
            id: destination.id,
            nodeIDs: destination.nodeIDs.union(nodeIDs),
            editingMode: destination.editingMode
        )

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: nextAreasByID
        )
        switch validateNoCrossAreaEdges(in: nextGraph) {
        case .success:
            break
        case .failure(let error):
            return .failure(error)
        }
        switch validate(in: nextGraph) {
        case .success:
            return .success(nextGraph)
        case .failure(let error):
            return .failure(error)
        }
    }

    /// Removes nodes from all areas.
    /// - Parameters:
    ///   - nodeIDs: Nodes to remove.
    ///   - graph: Source graph.
    /// - Returns: Graph with updated area memberships.
    public static func remove(nodeIDs: Set<CanvasNodeID>, in graph: CanvasGraph) -> CanvasGraph {
        var nextAreasByID = graph.areasByID
        for areaID in nextAreasByID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let area = nextAreasByID[areaID] else {
                continue
            }
            nextAreasByID[areaID] = CanvasArea(
                id: area.id,
                nodeIDs: area.nodeIDs.subtracting(nodeIDs),
                editingMode: area.editingMode
            )
        }
        return CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: nextAreasByID
        )
    }

    /// Validates that every edge stays within one area.
    /// - Parameter graph: Graph snapshot.
    /// - Returns: `.success(())` when all edges are intra-area.
    private static func validateNoCrossAreaEdges(in graph: CanvasGraph) -> Result<Void, CanvasAreaPolicyError> {
        for edgeID in graph.edgesByID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let edge = graph.edgesByID[edgeID] else {
                continue
            }
            switch areaID(containing: edge.fromNodeID, in: graph) {
            case .success(let fromAreaID):
                switch areaID(containing: edge.toNodeID, in: graph) {
                case .success(let toAreaID):
                    if fromAreaID != toAreaID {
                        return .failure(.crossAreaEdgeForbidden(edge.id))
                    }
                case .failure(let error):
                    return .failure(error)
                }
            case .failure(let error):
                return .failure(error)
            }
        }
        return .success(())
    }
}
