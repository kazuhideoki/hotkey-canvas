import Foundation

// Background: Node insertion should preserve nearby structure by moving connected areas as a unit.
// Responsibility: Build parent-child connected areas and resolve area collisions deterministically.
/// Pure domain service for hierarchy-aware area extraction and overlap resolution.
public enum CanvasAreaLayoutService {
    /// Epsilon used for floating-point stability checks.
    static let numericEpsilon: Double = 1e-9

    // MARK: - Public API

    /// Builds connected areas using parent-child links as an undirected graph.
    /// - Parameters:
    ///   - graph: Source graph snapshot.
    ///   - shapeKind: Shape strategy used when constructing area outlines.
    /// - Returns: Deterministically ordered connected areas.
    public static func makeParentChildAreas(
        in graph: CanvasGraph,
        shapeKind: CanvasAreaShapeKind = .rectangle
    ) -> [CanvasNodeArea] {
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
            let componentNodeIDs = bfsComponent(
                from: startNodeID,
                adjacencyByNodeID: adjacencyByNodeID,
                visited: &visited
            )
            let componentSet = Set(componentNodeIDs)
            let representativeNodeID = componentNodeIDs.min { $0.rawValue < $1.rawValue } ?? startNodeID
            let bounds = makeBounds(for: componentSet, in: graph)
            let shape = makeShape(
                for: componentSet,
                in: graph,
                shapeKind: shapeKind
            )

            areas.append(
                CanvasNodeArea(
                    id: representativeNodeID,
                    nodeIDs: componentSet,
                    bounds: bounds,
                    shape: shape
                )
            )
        }

        return areas.sorted { $0.id.rawValue < $1.id.rawValue }
    }

    /// Resolves area overlaps by moving areas on one of four cardinal directions.
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

        guard
            var state = makeInitialResolutionState(
                areas: areas,
                seedAreaID: seedAreaID,
                spacing: max(0, minimumSpacing)
            )
        else {
            return [:]
        }

        propagateOverlaps(
            state: &state,
            spacing: max(0, minimumSpacing),
            maxIterations: maxIterations
        )
        return state.translationsByAreaID.filter { _, translation in !translation.isZero }
    }
}

extension CanvasAreaLayoutService {
    struct OverlapResolutionState {
        var boundsByAreaID: [CanvasNodeID: CanvasRect]
        var shapesByAreaID: [CanvasNodeID: CanvasAreaShape]
        var translationsByAreaID: [CanvasNodeID: CanvasTranslation]
        var propagationQueue: [CanvasNodeID]
    }

    struct AreaOutline {
        let bounds: CanvasRect
        let shape: CanvasAreaShape
    }

    // MARK: - Internal Helpers

    private static func bfsComponent(
        from startNodeID: CanvasNodeID,
        adjacencyByNodeID: [CanvasNodeID: Set<CanvasNodeID>],
        visited: inout Set<CanvasNodeID>
    ) -> [CanvasNodeID] {
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

        return componentNodeIDs
    }

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

    private static func makeInitialResolutionState(
        areas: [CanvasNodeArea],
        seedAreaID: CanvasNodeID,
        spacing: Double
    ) -> OverlapResolutionState? {
        var boundsByAreaID: [CanvasNodeID: CanvasRect] = [:]
        var shapesByAreaID: [CanvasNodeID: CanvasAreaShape] = [:]
        for area in areas {
            boundsByAreaID[area.id] = area.bounds
            shapesByAreaID[area.id] = area.shape
        }

        guard
            let firstCollidedAreaID = firstOverlappedAreaID(
                of: seedAreaID,
                in: boundsByAreaID,
                shapesByAreaID: shapesByAreaID,
                spacing: spacing
            ),
            let seedBounds = boundsByAreaID[seedAreaID],
            let seedShape = shapesByAreaID[seedAreaID],
            let firstCollidedBounds = boundsByAreaID[firstCollidedAreaID],
            let firstCollidedShape = shapesByAreaID[firstCollidedAreaID]
        else {
            return nil
        }

        var state = OverlapResolutionState(
            boundsByAreaID: boundsByAreaID,
            shapesByAreaID: shapesByAreaID,
            translationsByAreaID: [:],
            propagationQueue: [seedAreaID, firstCollidedAreaID]
        )

        let initialSeparation = requiredSeparation(
            moving: AreaOutline(bounds: firstCollidedBounds, shape: firstCollidedShape),
            fixed: AreaOutline(bounds: seedBounds, shape: seedShape),
            spacing: spacing,
            tieBreakDirection: seedAreaID.rawValue < firstCollidedAreaID.rawValue ? 1 : -1
        )

        let didMoveSeed = applyTranslation(
            to: seedAreaID,
            translation: CanvasTranslation(
                dx: -(initialSeparation.dx / 2),
                dy: -(initialSeparation.dy / 2)
            ),
            state: &state
        )
        let didMoveCollided = applyTranslation(
            to: firstCollidedAreaID,
            translation: CanvasTranslation(
                dx: initialSeparation.dx / 2,
                dy: initialSeparation.dy / 2
            ),
            state: &state
        )

        guard didMoveSeed || didMoveCollided else {
            return nil
        }
        return state
    }

    private static func propagateOverlaps(
        state: inout OverlapResolutionState,
        spacing: Double,
        maxIterations: Int
    ) {
        var movementCount = 0

        while !state.propagationQueue.isEmpty, movementCount < maxIterations {
            let moverAreaID = state.propagationQueue.removeFirst()
            let targetAreaIDs = state.boundsByAreaID.keys
                .filter { $0 != moverAreaID }
                .sorted { $0.rawValue < $1.rawValue }

            for targetAreaID in targetAreaIDs where movementCount < maxIterations {
                if moveTargetAreaIfNeeded(
                    moverAreaID: moverAreaID,
                    targetAreaID: targetAreaID,
                    spacing: spacing,
                    state: &state
                ) {
                    movementCount += 1
                }
            }
        }
    }

    private static func moveTargetAreaIfNeeded(
        moverAreaID: CanvasNodeID,
        targetAreaID: CanvasNodeID,
        spacing: Double,
        state: inout OverlapResolutionState
    ) -> Bool {
        guard
            let moverBounds = state.boundsByAreaID[moverAreaID],
            let moverShape = state.shapesByAreaID[moverAreaID],
            let targetBounds = state.boundsByAreaID[targetAreaID],
            let targetShape = state.shapesByAreaID[targetAreaID]
        else {
            return false
        }

        guard
            areasOverlap(
                AreaOutline(bounds: moverBounds, shape: moverShape),
                AreaOutline(bounds: targetBounds, shape: targetShape),
                spacing: spacing
            )
        else {
            return false
        }

        let separation = requiredSeparation(
            moving: AreaOutline(bounds: targetBounds, shape: targetShape),
            fixed: AreaOutline(bounds: moverBounds, shape: moverShape),
            spacing: spacing,
            tieBreakDirection: moverAreaID.rawValue < targetAreaID.rawValue ? 1 : -1
        )

        let didMoveTarget = applyTranslation(
            to: targetAreaID,
            translation: separation,
            state: &state
        )
        guard didMoveTarget else {
            return false
        }

        state.propagationQueue.append(targetAreaID)
        return true
    }

    /// Finds the first area that overlaps the specified source area.
    /// - Parameters:
    ///   - areaID: Source area identifier.
    ///   - boundsByAreaID: Area bounds indexed by area identifier.
    ///   - shapesByAreaID: Area shapes indexed by area identifier.
    ///   - spacing: Required spacing between area bounds.
    /// - Returns: Overlapped area identifier, or `nil` when none overlaps.
    private static func firstOverlappedAreaID(
        of areaID: CanvasNodeID,
        in boundsByAreaID: [CanvasNodeID: CanvasRect],
        shapesByAreaID: [CanvasNodeID: CanvasAreaShape],
        spacing: Double
    ) -> CanvasNodeID? {
        guard
            let sourceBounds = boundsByAreaID[areaID],
            let sourceShape = shapesByAreaID[areaID]
        else {
            return nil
        }

        let source = AreaOutline(bounds: sourceBounds, shape: sourceShape)
        let sortedTargetAreaIDs = boundsByAreaID.keys
            .filter { $0 != areaID }
            .sorted { $0.rawValue < $1.rawValue }

        for targetAreaID in sortedTargetAreaIDs {
            guard
                let targetBounds = boundsByAreaID[targetAreaID],
                let targetShape = shapesByAreaID[targetAreaID]
            else {
                continue
            }

            if areasOverlap(
                source,
                AreaOutline(bounds: targetBounds, shape: targetShape),
                spacing: spacing
            ) {
                return targetAreaID
            }
        }

        return nil
    }

    /// Applies translation to area bounds and accumulates the area's total translation.
    /// - Parameters:
    ///   - areaID: Target area identifier.
    ///   - translation: Translation amount.
    ///   - state: Mutable overlap-resolution state.
    /// - Returns: `true` when a non-zero translation was applied.
    private static func applyTranslation(
        to areaID: CanvasNodeID,
        translation: CanvasTranslation,
        state: inout OverlapResolutionState
    ) -> Bool {
        guard abs(translation.dx) > numericEpsilon || abs(translation.dy) > numericEpsilon else {
            return false
        }
        guard
            let currentBounds = state.boundsByAreaID[areaID],
            let currentShape = state.shapesByAreaID[areaID]
        else {
            return false
        }

        state.boundsByAreaID[areaID] = currentBounds.translated(
            dx: translation.dx,
            dy: translation.dy
        )
        state.shapesByAreaID[areaID] = translateShape(
            currentShape,
            dx: translation.dx,
            dy: translation.dy
        )

        let currentTranslation = state.translationsByAreaID[areaID] ?? .zero
        state.translationsByAreaID[areaID] = CanvasTranslation(
            dx: currentTranslation.dx + translation.dx,
            dy: currentTranslation.dy + translation.dy
        )
        return true
    }
}
