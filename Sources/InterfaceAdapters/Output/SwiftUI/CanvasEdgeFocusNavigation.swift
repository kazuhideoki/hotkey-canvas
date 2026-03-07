// Background: Edge target navigation should follow rendered edge positions, including duplicated-edge lane offsets.
// Responsibility: Pick the next focused edge from rendered edge geometry inside the SwiftUI adapter layer.
import Domain
import SwiftUI

enum CanvasEdgeFocusNavigation {
    struct Context {
        let edges: [CanvasEdge]
        let nodesByID: [CanvasNodeID: CanvasNode]
        let branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double]
        let laneOffsetsByEdgeID: [CanvasEdgeID: CanvasEdgeRouting.EdgeLaneOffsets]
        let edgeShapeStyleByEdgeID: [CanvasEdgeID: CanvasAreaEdgeShapeStyle]
    }

    private static let preferredCrossAxisRatio: Double = 0.8
    private static let crossAxisWeight: Double = 2.5
    private static let anglePenaltyWeight: Double = 32

    static func nextFocusedEdgeID(
        in context: Context,
        currentEdgeID: CanvasEdgeID?,
        direction: CanvasFocusDirection
    ) -> CanvasEdgeID? {
        let sortedEdges = context.edges.sorted(by: isEdgeOrdered)
        guard !sortedEdges.isEmpty else {
            return nil
        }

        let focusPointsByEdgeID = Dictionary(
            uniqueKeysWithValues: sortedEdges.compactMap { edge in
                focusPoint(
                    for: edge,
                    nodesByID: context.nodesByID,
                    branchCoordinateByParentAndDirection: context.branchCoordinateByParentAndDirection,
                    laneOffsetsByEdgeID: context.laneOffsetsByEdgeID,
                    edgeShapeStyle: context.edgeShapeStyleByEdgeID[edge.id] ?? .curved
                ).map { (edge.id, $0) }
            }
        )
        guard !focusPointsByEdgeID.isEmpty else {
            return nil
        }

        let fallbackEdgeID = sortedEdges.first(where: { focusPointsByEdgeID[$0.id] != nil })?.id
        guard let fallbackEdgeID else {
            return nil
        }

        let currentResolvedEdgeID =
            currentEdgeID.flatMap { focusPointsByEdgeID[$0] != nil ? $0 : nil } ?? fallbackEdgeID
        guard let currentPoint = focusPointsByEdgeID[currentResolvedEdgeID] else {
            return fallbackEdgeID
        }

        let directionalCandidates = sortedEdges.compactMap { edge -> EdgeCandidate? in
            guard edge.id != currentResolvedEdgeID else {
                return nil
            }
            guard let targetPoint = focusPointsByEdgeID[edge.id] else {
                return nil
            }
            return makeCandidate(
                edgeID: edge.id,
                currentPoint: currentPoint,
                targetPoint: targetPoint,
                direction: direction
            )
        }

        guard !directionalCandidates.isEmpty else {
            return currentResolvedEdgeID
        }

        let preferredCandidates = directionalCandidates.filter(isPreferredCandidate)
        let candidatePool = preferredCandidates.isEmpty ? directionalCandidates : preferredCandidates
        return candidatePool.min(by: isBetterCandidate)?.edgeID ?? currentResolvedEdgeID
    }
}

extension CanvasEdgeFocusNavigation {
    private struct DirectionComponents {
        let mainAxisDistance: Double
        let crossAxisDistance: Double
    }

    private struct EdgeCandidate {
        let edgeID: CanvasEdgeID
        let mainAxisDistance: Double
        let crossAxisDistance: Double
        let squaredDistance: Double
        let score: Double
    }

    private static func focusPoint(
        for edge: CanvasEdge,
        nodesByID: [CanvasNodeID: CanvasNode],
        branchCoordinateByParentAndDirection: [CanvasEdgeRouting.BranchKey: Double],
        laneOffsetsByEdgeID: [CanvasEdgeID: CanvasEdgeRouting.EdgeLaneOffsets],
        edgeShapeStyle: CanvasAreaEdgeShapeStyle
    ) -> CGPoint? {
        guard
            let path = CanvasEdgeRouting.path(
                for: edge,
                nodesByID: nodesByID,
                branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection,
                laneOffsetsByEdgeID: laneOffsetsByEdgeID,
                edgeShapeStyle: edgeShapeStyle
            )
        else {
            return nil
        }
        let rect = path.boundingRect
        guard !rect.isNull else {
            return nil
        }
        return CGPoint(x: rect.midX, y: rect.midY)
    }

    private static func makeCandidate(
        edgeID: CanvasEdgeID,
        currentPoint: CGPoint,
        targetPoint: CGPoint,
        direction: CanvasFocusDirection
    ) -> EdgeCandidate? {
        let deltaX = targetPoint.x - currentPoint.x
        let deltaY = targetPoint.y - currentPoint.y
        let components = directionComponents(deltaX: deltaX, deltaY: deltaY, direction: direction)
        guard components.mainAxisDistance > 0 else {
            return nil
        }

        let score = calculateScore(
            mainAxisDistance: components.mainAxisDistance,
            crossAxisDistance: components.crossAxisDistance
        )
        return EdgeCandidate(
            edgeID: edgeID,
            mainAxisDistance: components.mainAxisDistance,
            crossAxisDistance: components.crossAxisDistance,
            squaredDistance: (deltaX * deltaX) + (deltaY * deltaY),
            score: score
        )
    }

    private static func directionComponents(
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

    private static func calculateScore(
        mainAxisDistance: Double,
        crossAxisDistance: Double
    ) -> Double {
        let anglePenalty = crossAxisDistance / mainAxisDistance
        return mainAxisDistance
            + (crossAxisDistance * crossAxisWeight)
            + (anglePenalty * anglePenaltyWeight)
    }

    private static func isPreferredCandidate(_ candidate: EdgeCandidate) -> Bool {
        candidate.crossAxisDistance <= (candidate.mainAxisDistance * preferredCrossAxisRatio)
    }

    private static func isBetterCandidate(_ lhs: EdgeCandidate, _ rhs: EdgeCandidate) -> Bool {
        if lhs.score != rhs.score {
            return lhs.score < rhs.score
        }
        if lhs.squaredDistance != rhs.squaredDistance {
            return lhs.squaredDistance < rhs.squaredDistance
        }
        if lhs.crossAxisDistance != rhs.crossAxisDistance {
            return lhs.crossAxisDistance < rhs.crossAxisDistance
        }
        return lhs.edgeID.rawValue < rhs.edgeID.rawValue
    }

    private static func isEdgeOrdered(_ lhs: CanvasEdge, _ rhs: CanvasEdge) -> Bool {
        if lhs.fromNodeID.rawValue != rhs.fromNodeID.rawValue {
            return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
        }
        if lhs.toNodeID.rawValue != rhs.toNodeID.rawValue {
            return lhs.toNodeID.rawValue < rhs.toNodeID.rawValue
        }
        return lhs.id.rawValue < rhs.id.rawValue
    }
}
