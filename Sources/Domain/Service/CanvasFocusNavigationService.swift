// Background: Directional focus movement must stay deterministic and independent from UI frameworks.
// Responsibility: Select the next focused node by direction-aware scoring of node positions.
/// Pure domain service that resolves next focused node for directional navigation.
public enum CanvasFocusNavigationService {
    private static let preferredCrossAxisRatio: Double = 0.8
    private static let crossAxisWeight: Double = 2.5
    private static let anglePenaltyWeight: Double = 32

    /// Resolves the next focused node identifier for directional movement.
    /// - Parameters:
    ///   - graph: Source graph snapshot.
    ///   - direction: Requested focus movement direction.
    /// - Returns: Next focused node identifier, or `nil` when the graph is empty.
    public static func nextFocusedNodeID(
        in graph: CanvasGraph,
        moving direction: CanvasFocusDirection
    ) -> CanvasNodeID? {
        let sortedNodes = sortedNodes(in: graph)
        guard !sortedNodes.isEmpty else {
            return nil
        }

        let fallbackNode = sortedNodes[0]
        let currentNode = graph.focusedNodeID.flatMap { graph.nodesByID[$0] } ?? fallbackNode

        let directionalCandidates =
            sortedNodes
            .filter { $0.id != currentNode.id }
            .compactMap { makeCandidate(to: $0, from: currentNode, direction: direction) }

        guard !directionalCandidates.isEmpty else {
            return currentNode.id
        }

        let preferredCandidates = directionalCandidates.filter(isPreferredCandidate)
        let candidatePool = preferredCandidates.isEmpty ? directionalCandidates : preferredCandidates
        let nextCandidate = candidatePool.min(by: isBetterCandidate)

        return nextCandidate?.node.id ?? currentNode.id
    }

    /// Resolves the next focused edge identifier for directional movement.
    /// - Parameters:
    ///   - graph: Source graph snapshot.
    ///   - currentEdgeID: Current focused edge identifier.
    ///   - direction: Requested focus movement direction.
    /// - Returns: Next focused edge identifier, or `nil` when the edge set is empty.
    public static func nextFocusedEdgeID(
        in graph: CanvasGraph,
        from currentEdgeID: CanvasEdgeID?,
        moving direction: CanvasFocusDirection
    ) -> CanvasEdgeID? {
        let sortedEdges = sortedEdges(in: graph)
        guard !sortedEdges.isEmpty else {
            return nil
        }

        let fallbackEdge = sortedEdges[0]
        let currentEdge = currentEdgeID.flatMap { graph.edgesByID[$0] } ?? fallbackEdge

        let directionalCandidates =
            sortedEdges
            .filter { $0.id != currentEdge.id }
            .compactMap { edge in
                makeEdgeCandidate(
                    to: edge,
                    from: currentEdge,
                    direction: direction,
                    in: graph
                )
            }

        guard !directionalCandidates.isEmpty else {
            return currentEdge.id
        }

        let preferredCandidates = directionalCandidates.filter(isPreferredEdgeCandidate)
        let candidatePool = preferredCandidates.isEmpty ? directionalCandidates : preferredCandidates
        let nextCandidate = candidatePool.min(by: isBetterEdgeCandidate)

        return nextCandidate?.edge.id ?? currentEdge.id
    }
}

extension CanvasFocusNavigationService {
    /// Builds a candidate only when the node exists in the requested direction.
    /// - Parameters:
    ///   - node: Candidate destination node.
    ///   - currentNode: Current focused node.
    ///   - direction: Requested movement direction.
    /// - Returns: Directional candidate, or `nil` when it is not in front of the direction axis.
    fileprivate static func makeCandidate(
        to node: CanvasNode,
        from currentNode: CanvasNode,
        direction: CanvasFocusDirection
    ) -> FocusCandidate? {
        let currentCenter = nodeCenter(for: currentNode)
        let targetCenter = nodeCenter(for: node)
        let deltaX = targetCenter.x - currentCenter.x
        let deltaY = targetCenter.y - currentCenter.y

        let components = directionComponents(deltaX: deltaX, deltaY: deltaY, direction: direction)
        guard components.mainAxisDistance > 0 else {
            return nil
        }

        let score = calculateScore(
            mainAxisDistance: components.mainAxisDistance,
            crossAxisDistance: components.crossAxisDistance
        )
        return FocusCandidate(
            node: node,
            mainAxisDistance: components.mainAxisDistance,
            crossAxisDistance: components.crossAxisDistance,
            squaredDistance: (deltaX * deltaX) + (deltaY * deltaY),
            score: score
        )
    }

    /// Converts absolute delta values into direction-specific main/cross axis components.
    /// - Parameters:
    ///   - deltaX: Delta in x-axis from current node center to target node center.
    ///   - deltaY: Delta in y-axis from current node center to target node center.
    ///   - direction: Requested movement direction.
    /// - Returns: Main axis distance and absolute cross axis distance.
    fileprivate static func directionComponents(
        deltaX: Double,
        deltaY: Double,
        direction: CanvasFocusDirection
    ) -> DirectionComponents {
        switch direction {
        case .up:
            return DirectionComponents(mainAxisDistance: -deltaY, crossAxisDistance: abs(deltaX))
        case .down:
            return DirectionComponents(mainAxisDistance: deltaY, crossAxisDistance: abs(deltaX))
        case .left:
            return DirectionComponents(mainAxisDistance: -deltaX, crossAxisDistance: abs(deltaY))
        case .right:
            return DirectionComponents(mainAxisDistance: deltaX, crossAxisDistance: abs(deltaY))
        }
    }

    /// Calculates direction-aware score with higher penalty on cross-axis drift.
    /// - Parameters:
    ///   - mainAxisDistance: Positive distance on requested direction axis.
    ///   - crossAxisDistance: Absolute distance on perpendicular axis.
    /// - Returns: Comparable score where lower values are preferred.
    fileprivate static func calculateScore(
        mainAxisDistance: Double,
        crossAxisDistance: Double
    ) -> Double {
        let anglePenalty = crossAxisDistance / mainAxisDistance
        return mainAxisDistance
            + (crossAxisDistance * crossAxisWeight)
            + (anglePenalty * anglePenaltyWeight)
    }

    /// Returns whether a candidate stays within the preferred directional corridor.
    /// - Parameter candidate: Candidate to evaluate.
    /// - Returns: `true` when cross-axis drift is relatively small.
    fileprivate static func isPreferredCandidate(_ candidate: FocusCandidate) -> Bool {
        candidate.crossAxisDistance <= (candidate.mainAxisDistance * preferredCrossAxisRatio)
    }

    /// Defines deterministic ordering between two candidates.
    /// - Parameters:
    ///   - lhs: Left-hand candidate.
    ///   - rhs: Right-hand candidate.
    /// - Returns: `true` when lhs is preferred.
    fileprivate static func isBetterCandidate(_ lhs: FocusCandidate, _ rhs: FocusCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }
        if lhs.squaredDistance != rhs.squaredDistance {
            return lhs.squaredDistance < rhs.squaredDistance
        }
        if lhs.crossAxisDistance != rhs.crossAxisDistance {
            return lhs.crossAxisDistance < rhs.crossAxisDistance
        }
        return lhs.node.id.rawValue < rhs.node.id.rawValue
    }

    /// Returns nodes sorted deterministically by top-left position and identifier.
    /// - Parameter graph: Source graph snapshot.
    /// - Returns: Sorted node array.
    fileprivate static func sortedNodes(in graph: CanvasGraph) -> [CanvasNode] {
        graph.nodesByID.values.sorted { lhs, rhs in
            if lhs.bounds.y != rhs.bounds.y {
                return lhs.bounds.y < rhs.bounds.y
            }
            if lhs.bounds.x != rhs.bounds.x {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    /// Returns center point of a node bounds.
    /// - Parameter node: Target node.
    /// - Returns: Node center point.
    fileprivate static func nodeCenter(for node: CanvasNode) -> (x: Double, y: Double) {
        (
            x: node.bounds.x + (node.bounds.width / 2),
            y: node.bounds.y + (node.bounds.height / 2)
        )
    }

    fileprivate static func sortedEdges(in graph: CanvasGraph) -> [CanvasEdge] {
        graph.edgesByID.values.sorted { lhs, rhs in
            if lhs.fromNodeID.rawValue != rhs.fromNodeID.rawValue {
                return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
            }
            if lhs.toNodeID.rawValue != rhs.toNodeID.rawValue {
                return lhs.toNodeID.rawValue < rhs.toNodeID.rawValue
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }

    fileprivate static func edgeCenter(for edge: CanvasEdge, in graph: CanvasGraph) -> (x: Double, y: Double)? {
        guard
            let fromNode = graph.nodesByID[edge.fromNodeID],
            let toNode = graph.nodesByID[edge.toNodeID]
        else {
            return nil
        }
        let fromCenter = nodeCenter(for: fromNode)
        let toCenter = nodeCenter(for: toNode)
        return (
            x: (fromCenter.x + toCenter.x) / 2,
            y: (fromCenter.y + toCenter.y) / 2
        )
    }

    fileprivate static func makeEdgeCandidate(
        to edge: CanvasEdge,
        from currentEdge: CanvasEdge,
        direction: CanvasFocusDirection,
        in graph: CanvasGraph
    ) -> EdgeFocusCandidate? {
        guard
            let currentCenter = edgeCenter(for: currentEdge, in: graph),
            let targetCenter = edgeCenter(for: edge, in: graph)
        else {
            return nil
        }
        let deltaX = targetCenter.x - currentCenter.x
        let deltaY = targetCenter.y - currentCenter.y
        let components = directionComponents(deltaX: deltaX, deltaY: deltaY, direction: direction)
        guard components.mainAxisDistance > 0 else {
            return nil
        }
        let score = calculateScore(
            mainAxisDistance: components.mainAxisDistance,
            crossAxisDistance: components.crossAxisDistance
        )
        return EdgeFocusCandidate(
            edge: edge,
            mainAxisDistance: components.mainAxisDistance,
            crossAxisDistance: components.crossAxisDistance,
            squaredDistance: (deltaX * deltaX) + (deltaY * deltaY),
            score: score
        )
    }

    fileprivate static func isPreferredEdgeCandidate(_ candidate: EdgeFocusCandidate) -> Bool {
        candidate.crossAxisDistance <= (candidate.mainAxisDistance * preferredCrossAxisRatio)
    }

    fileprivate static func isBetterEdgeCandidate(_ lhs: EdgeFocusCandidate, _ rhs: EdgeFocusCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }
        if lhs.squaredDistance != rhs.squaredDistance {
            return lhs.squaredDistance < rhs.squaredDistance
        }
        if lhs.crossAxisDistance != rhs.crossAxisDistance {
            return lhs.crossAxisDistance < rhs.crossAxisDistance
        }
        return lhs.edge.id.rawValue < rhs.edge.id.rawValue
    }
}

/// Direction-specific distance components used in candidate scoring.
private struct DirectionComponents {
    let mainAxisDistance: Double
    let crossAxisDistance: Double
}

/// Immutable value used for ordering directional focus candidates.
private struct FocusCandidate {
    let node: CanvasNode
    let mainAxisDistance: Double
    let crossAxisDistance: Double
    let squaredDistance: Double
    let score: Double
}

/// Immutable value used for ordering directional edge-focus candidates.
private struct EdgeFocusCandidate {
    let edge: CanvasEdge
    let mainAxisDistance: Double
    let crossAxisDistance: Double
    let squaredDistance: Double
    let score: Double
}
