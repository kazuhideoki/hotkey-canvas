import Foundation

// Background: Node insertion should preserve nearby structure by moving connected areas as a unit.
// Responsibility: Build parent-child connected areas and resolve area collisions deterministically.
/// Pure domain service for hierarchy-aware area extraction and overlap resolution.
public enum CanvasAreaLayoutService {
    /// Epsilon used for floating-point stability checks.
    private static let numericEpsilon: Double = 1e-9

    // MARK: - Public API

    /// Builds connected areas using parent-child links as an undirected graph.
    /// - Parameter graph: Source graph snapshot.
    /// - Returns: Deterministically ordered connected areas.
    public static func makeParentChildAreas(in graph: CanvasGraph) -> [CanvasNodeArea] {
        let sortedNodeIDs = graph.nodesByID.keys.sorted { $0.rawValue < $1.rawValue }
        guard !sortedNodeIDs.isEmpty else {
            return []
        }

        var adjacencyByNodeID: [CanvasNodeID: Set<CanvasNodeID>] = [:]
        for nodeID in sortedNodeIDs {
            adjacencyByNodeID[nodeID] = []
        }

        for edge in graph.edgesByID.values where edge.relationType == .parentChild {
            guard graph.nodesByID[edge.fromNodeID] != nil, graph.nodesByID[edge.toNodeID] != nil else {
                continue
            }
            adjacencyByNodeID[edge.fromNodeID, default: []].insert(edge.toNodeID)
            adjacencyByNodeID[edge.toNodeID, default: []].insert(edge.fromNodeID)
        }

        var visited: Set<CanvasNodeID> = []
        var areas: [CanvasNodeArea] = []

        for startNodeID in sortedNodeIDs where !visited.contains(startNodeID) {
            var queue: [CanvasNodeID] = [startNodeID]
            var componentNodeIDs: [CanvasNodeID] = []
            visited.insert(startNodeID)

            while !queue.isEmpty {
                let currentNodeID = queue.removeFirst()
                componentNodeIDs.append(currentNodeID)

                let neighbors = adjacencyByNodeID[currentNodeID, default: []]
                    .sorted { $0.rawValue < $1.rawValue }
                for neighborNodeID in neighbors where !visited.contains(neighborNodeID) {
                    visited.insert(neighborNodeID)
                    queue.append(neighborNodeID)
                }
            }

            let componentSet = Set(componentNodeIDs)
            let representativeNodeID = componentNodeIDs.min { $0.rawValue < $1.rawValue } ?? startNodeID
            let bounds = makeBounds(for: componentSet, in: graph)
            areas.append(
                CanvasNodeArea(
                    id: representativeNodeID,
                    nodeIDs: componentSet,
                    bounds: bounds
                )
            )
        }

        return areas.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// Resolves area overlaps by moving areas on the line between area centers.
    /// - Parameters:
    ///   - areas: Areas to resolve.
    ///   - seedAreaID: Area where a new node was inserted.
    ///   - minimumSpacing: Required spacing between resolved area bounds.
    ///   - maxIterations: Maximum movement operations before termination.
    /// - Returns: Accumulated translation per area identifier.
    public static func resolveOverlaps(
        areas: [CanvasNodeArea],
        seedAreaID: CanvasNodeID,
        minimumSpacing: Double = 0,
        maxIterations: Int = 1_024
    ) -> [CanvasNodeID: CanvasTranslation] {
        guard areas.count > 1, maxIterations > 0 else {
            return [:]
        }

        var boundsByAreaID: [CanvasNodeID: CanvasRect] = [:]
        for area in areas {
            boundsByAreaID[area.id] = area.bounds
        }
        guard boundsByAreaID[seedAreaID] != nil else {
            return [:]
        }

        let spacing = max(0, minimumSpacing)
        var translationsByAreaID: [CanvasNodeID: CanvasTranslation] = [:]
        var propagationQueue: [CanvasNodeID] = []

        if let firstCollidedAreaID = firstOverlappedAreaID(
            of: seedAreaID,
            in: boundsByAreaID,
            spacing: spacing
        ) {
            guard let seedBounds = boundsByAreaID[seedAreaID],
                let firstCollidedBounds = boundsByAreaID[firstCollidedAreaID]
            else {
                return [:]
            }

            let initialSeparation = requiredSeparation(
                moving: firstCollidedBounds,
                awayFrom: seedBounds,
                spacing: spacing,
                tieBreakDirection: seedAreaID.rawValue < firstCollidedAreaID.rawValue ? 1 : -1
            )
            applyTranslation(
                to: seedAreaID,
                dx: -(initialSeparation.dx / 2),
                dy: -(initialSeparation.dy / 2),
                boundsByAreaID: &boundsByAreaID,
                translationsByAreaID: &translationsByAreaID
            )
            applyTranslation(
                to: firstCollidedAreaID,
                dx: initialSeparation.dx / 2,
                dy: initialSeparation.dy / 2,
                boundsByAreaID: &boundsByAreaID,
                translationsByAreaID: &translationsByAreaID
            )
            propagationQueue.append(seedAreaID)
            propagationQueue.append(firstCollidedAreaID)
        } else {
            return [:]
        }

        var movementCount = 0
        while !propagationQueue.isEmpty, movementCount < maxIterations {
            let moverAreaID = propagationQueue.removeFirst()
            guard let moverBounds = boundsByAreaID[moverAreaID] else {
                continue
            }

            let targetAreaIDs = boundsByAreaID.keys
                .filter { $0 != moverAreaID }
                .sorted { $0.rawValue < $1.rawValue }

            for targetAreaID in targetAreaIDs {
                guard let targetBounds = boundsByAreaID[targetAreaID] else {
                    continue
                }
                guard boundsOverlap(moverBounds, targetBounds, spacing: spacing) else {
                    continue
                }

                let separation = requiredSeparation(
                    moving: targetBounds,
                    awayFrom: moverBounds,
                    spacing: spacing,
                    tieBreakDirection: moverAreaID.rawValue < targetAreaID.rawValue ? 1 : -1
                )
                applyTranslation(
                    to: targetAreaID,
                    dx: separation.dx,
                    dy: separation.dy,
                    boundsByAreaID: &boundsByAreaID,
                    translationsByAreaID: &translationsByAreaID
                )
                propagationQueue.append(targetAreaID)
                movementCount += 1

                if movementCount >= maxIterations {
                    break
                }
            }
        }

        return translationsByAreaID.filter { _, translation in
            !translation.isZero
        }
    }
}

extension CanvasAreaLayoutService {
    // MARK: - Internal Geometry Helpers

    /// Calculates a single area bounding rectangle from contained node bounds.
    /// - Parameters:
    ///   - nodeIDs: Node identifiers included in the area.
    ///   - graph: Graph snapshot containing node bounds.
    /// - Returns: Axis-aligned rectangle enclosing all nodes in the area.
    private static func makeBounds(for nodeIDs: Set<CanvasNodeID>, in graph: CanvasGraph) -> CanvasRect {
        guard let firstNodeID = nodeIDs.first, let firstNode = graph.nodesByID[firstNodeID] else {
            return CanvasRect(minX: 0, minY: 0, width: 0, height: 0)
        }

        var minX = firstNode.bounds.x
        var minY = firstNode.bounds.y
        var maxX = firstNode.bounds.x + firstNode.bounds.width
        var maxY = firstNode.bounds.y + firstNode.bounds.height

        for nodeID in nodeIDs {
            guard let node = graph.nodesByID[nodeID] else {
                continue
            }
            minX = min(minX, node.bounds.x)
            minY = min(minY, node.bounds.y)
            maxX = max(maxX, node.bounds.x + node.bounds.width)
            maxY = max(maxY, node.bounds.y + node.bounds.height)
        }

        return CanvasRect(
            minX: minX,
            minY: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    /// Finds the first area that overlaps the specified source area.
    /// - Parameters:
    ///   - areaID: Source area identifier.
    ///   - boundsByAreaID: Area bounds indexed by area identifier.
    ///   - spacing: Required spacing between area bounds.
    /// - Returns: Overlapped area identifier, or `nil` when none overlaps.
    private static func firstOverlappedAreaID(
        of areaID: CanvasNodeID,
        in boundsByAreaID: [CanvasNodeID: CanvasRect],
        spacing: Double
    ) -> CanvasNodeID? {
        guard let sourceBounds = boundsByAreaID[areaID] else {
            return nil
        }

        let sortedTargetAreaIDs = boundsByAreaID.keys
            .filter { $0 != areaID }
            .sorted { $0.rawValue < $1.rawValue }

        for targetAreaID in sortedTargetAreaIDs {
            guard let targetBounds = boundsByAreaID[targetAreaID] else {
                continue
            }
            if boundsOverlap(sourceBounds, targetBounds, spacing: spacing) {
                return targetAreaID
            }
        }

        return nil
    }

    /// Returns whether two area bounds overlap after spacing expansion.
    /// - Parameters:
    ///   - lhs: First area bounds.
    ///   - rhs: Second area bounds.
    ///   - spacing: Required spacing between areas.
    /// - Returns: `true` when the two expanded rectangles overlap.
    private static func boundsOverlap(
        _ lhs: CanvasRect,
        _ rhs: CanvasRect,
        spacing: Double
    ) -> Bool {
        let halfSpacing = max(0, spacing) / 2
        let expandedLHS = lhs.expanded(horizontal: halfSpacing, vertical: halfSpacing)
        let expandedRHS = rhs.expanded(horizontal: halfSpacing, vertical: halfSpacing)
        return expandedLHS.intersects(expandedRHS)
    }

    /// Computes the translation needed to move one area out of another along center direction.
    /// - Parameters:
    ///   - targetBounds: Area bounds to be moved.
    ///   - fixedBounds: Area bounds that stays fixed.
    ///   - spacing: Required spacing between area bounds.
    ///   - tieBreakDirection: Fallback horizontal direction when area centers are identical.
    /// - Returns: Translation that resolves overlap for the target area.
    private static func requiredSeparation(
        moving targetBounds: CanvasRect,
        awayFrom fixedBounds: CanvasRect,
        spacing: Double,
        tieBreakDirection: Double
    ) -> CanvasTranslation {
        let halfSpacing = max(0, spacing) / 2
        let expandedFixed = fixedBounds.expanded(horizontal: halfSpacing, vertical: halfSpacing)
        let expandedTarget = targetBounds.expanded(horizontal: halfSpacing, vertical: halfSpacing)

        let overlapX = min(expandedFixed.maxX, expandedTarget.maxX) - max(expandedFixed.minX, expandedTarget.minX)
        let overlapY = min(expandedFixed.maxY, expandedTarget.maxY) - max(expandedFixed.minY, expandedTarget.minY)
        guard overlapX > 0, overlapY > 0 else {
            return .zero
        }

        var directionX = expandedTarget.centerX - expandedFixed.centerX
        var directionY = expandedTarget.centerY - expandedFixed.centerY
        if abs(directionX) <= numericEpsilon, abs(directionY) <= numericEpsilon {
            directionX = tieBreakDirection >= 0 ? 1 : -1
            directionY = 0
        }

        let directionLength = sqrt((directionX * directionX) + (directionY * directionY))
        guard directionLength > numericEpsilon else {
            return .zero
        }

        let unitX = directionX / directionLength
        let unitY = directionY / directionLength

        var distanceCandidates: [Double] = []
        if abs(unitX) > numericEpsilon {
            distanceCandidates.append(overlapX / abs(unitX))
        }
        if abs(unitY) > numericEpsilon {
            distanceCandidates.append(overlapY / abs(unitY))
        }
        guard let distance = distanceCandidates.min() else {
            return .zero
        }

        return CanvasTranslation(
            dx: unitX * distance,
            dy: unitY * distance
        )
    }

    /// Applies translation to area bounds and accumulates the area's total translation.
    /// - Parameters:
    ///   - areaID: Target area identifier.
    ///   - dx: Horizontal translation amount.
    ///   - dy: Vertical translation amount.
    ///   - boundsByAreaID: Mutable area bounds dictionary.
    ///   - translationsByAreaID: Mutable accumulated translation dictionary.
    private static func applyTranslation(
        to areaID: CanvasNodeID,
        dx: Double,
        dy: Double,
        boundsByAreaID: inout [CanvasNodeID: CanvasRect],
        translationsByAreaID: inout [CanvasNodeID: CanvasTranslation]
    ) {
        guard abs(dx) > numericEpsilon || abs(dy) > numericEpsilon else {
            return
        }
        guard let currentBounds = boundsByAreaID[areaID] else {
            return
        }

        boundsByAreaID[areaID] = currentBounds.translated(dx: dx, dy: dy)
        let currentTranslation = translationsByAreaID[areaID] ?? .zero
        translationsByAreaID[areaID] = CanvasTranslation(
            dx: currentTranslation.dx + dx,
            dy: currentTranslation.dy + dy
        )
    }
}
