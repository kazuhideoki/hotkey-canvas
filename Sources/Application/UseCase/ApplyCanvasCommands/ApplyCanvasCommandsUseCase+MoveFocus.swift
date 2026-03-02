import Domain

// Background: Keyboard-driven navigation needs deterministic next-focus selection.
// Responsibility: Resolve next focus by delegating directional candidate selection to domain service.
extension ApplyCanvasCommandsUseCase {
    /// Moves focus in the visible graph and requests focus normalization without layout recomputation.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - direction: Direction for navigation.
    /// - Returns: Mutation result with updated focus, or no-op when navigation fails.
    func moveFocus(in graph: CanvasGraph, direction: CanvasFocusDirection) -> CanvasMutationResult {
        if case .area(let focusedAreaID) = graph.focusedElement {
            return moveAreaFocus(
                in: graph,
                direction: direction,
                focusedAreaID: focusedAreaID
            )
        }

        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph)
        guard
            let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(
                in: visibleGraph,
                moving: direction
            )
        else {
            return noOpMutationResult(for: graph)
        }

        let nextSelectedNodeIDs = CanvasSelectionService.normalizedSelectedNodeIDs(
            from: [nextFocusedNodeID],
            in: graph,
            focusedNodeID: nextFocusedNodeID
        )
        guard
            graph.focusedNodeID != nextFocusedNodeID
                || graph.selectedNodeIDs != nextSelectedNodeIDs
        else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nextFocusedNodeID,
            focusedElement: .node(nextFocusedNodeID),
            selectedNodeIDs: nextSelectedNodeIDs,
            selectedEdgeIDs: [],
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: true
            )
        )
    }

    /// Moves focus across areas and re-anchors to root/oldest node of the destination area.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - direction: Horizontal direction used to choose adjacent area.
    /// - Returns: Mutation result with updated focus/selection, or no-op when no destination exists.
    func moveFocusAcrossAreasToRoot(in graph: CanvasGraph, direction: CanvasFocusDirection) -> CanvasMutationResult {
        guard direction == .left || direction == .right else {
            return noOpMutationResult(for: graph)
        }

        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph)
        let visibleNodeIDs = Set(visibleGraph.nodesByID.keys)
        guard
            let currentAreaID = focusedAreaID(in: graph),
            let nextAreaID = acrossAreaDestinationAreaID(
                in: visibleGraph,
                moving: direction,
                from: currentAreaID
            ),
            let nextArea = graph.areasByID[nextAreaID]
        else {
            return noOpMutationResult(for: graph)
        }

        guard
            let nextFocusedNodeID = nextAreaAnchorNodeID(
                area: nextArea,
                in: graph,
                visibleNodeIDs: visibleNodeIDs
            )
        else {
            return noOpMutationResult(for: graph)
        }

        let nextSelectedNodeIDs = CanvasSelectionService.normalizedSelectedNodeIDs(
            from: [nextFocusedNodeID],
            in: graph,
            focusedNodeID: nextFocusedNodeID
        )
        let nextFocusedElement: CanvasFocusedElement =
            if case .area = graph.focusedElement {
                .area(nextAreaID)
            } else {
                .node(nextFocusedNodeID)
            }
        return updateFocusedNodeAndElement(
            in: graph,
            focusedNodeID: nextFocusedNodeID,
            focusedElement: nextFocusedElement,
            selectedNodeIDs: nextSelectedNodeIDs
        )
    }

    /// Extends the current selected-node set while moving focus in the visible graph.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - direction: Direction for selection extension.
    /// - Returns: Mutation result with updated focus and selected-node set.
    func extendSelection(in graph: CanvasGraph, direction: CanvasFocusDirection) -> CanvasMutationResult {
        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph)
        guard
            let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(
                in: visibleGraph,
                moving: direction
            )
        else {
            return noOpMutationResult(for: graph)
        }

        var extendedSelectedNodeIDs = graph.selectedNodeIDs
        if let focusedNodeID = graph.focusedNodeID {
            extendedSelectedNodeIDs.insert(focusedNodeID)
        }
        extendedSelectedNodeIDs.insert(nextFocusedNodeID)
        let nextSelectedNodeIDs = CanvasSelectionService.normalizedSelectedNodeIDs(
            from: extendedSelectedNodeIDs,
            in: graph,
            focusedNodeID: nextFocusedNodeID
        )

        guard
            graph.focusedNodeID != nextFocusedNodeID
                || graph.selectedNodeIDs != nextSelectedNodeIDs
        else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nextFocusedNodeID,
            focusedElement: .node(nextFocusedNodeID),
            selectedNodeIDs: nextSelectedNodeIDs,
            selectedEdgeIDs: [],
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: true
            )
        )
    }

    private func moveAreaFocus(
        in graph: CanvasGraph,
        direction: CanvasFocusDirection,
        focusedAreaID: CanvasAreaID
    ) -> CanvasMutationResult {
        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: graph)
        let visibleNodeIDs = Set(visibleGraph.nodesByID.keys)
        guard
            let nextAreaID = nextFocusedAreaID(
                in: visibleGraph,
                moving: direction,
                from: focusedAreaID
            ),
            let nextArea = graph.areasByID[nextAreaID]
        else {
            return noOpMutationResult(for: graph)
        }

        guard let nextFocusedNodeID = areaAnchorNodeID(in: nextArea, graph: graph, visibleNodeIDs: visibleNodeIDs)
        else {
            return noOpMutationResult(for: graph)
        }

        let nextSelectedNodeIDs = CanvasSelectionService.normalizedSelectedNodeIDs(
            from: [nextFocusedNodeID],
            in: graph,
            focusedNodeID: nextFocusedNodeID
        )
        let nextFocusedElement: CanvasFocusedElement = .area(nextAreaID)
        guard
            graph.focusedNodeID != nextFocusedNodeID
                || graph.focusedElement != nextFocusedElement
                || graph.selectedNodeIDs != nextSelectedNodeIDs
                || !graph.selectedEdgeIDs.isEmpty
        else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: nextFocusedNodeID,
            focusedElement: nextFocusedElement,
            selectedNodeIDs: nextSelectedNodeIDs,
            selectedEdgeIDs: [],
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: true
            )
        )
    }

    private func nextFocusedAreaID(
        in graph: CanvasGraph,
        moving direction: CanvasFocusDirection,
        from focusedAreaID: CanvasAreaID
    ) -> CanvasAreaID? {
        let areaCenters = areaCenterByID(in: graph)
        guard let currentCenter = areaCenters[focusedAreaID] else {
            return nil
        }

        let sortedAreaIDs = areaCenters.keys.sorted { $0.rawValue < $1.rawValue }
        var bestCandidate: (id: CanvasAreaID, score: Double)?

        for areaID in sortedAreaIDs where areaID != focusedAreaID {
            guard let center = areaCenters[areaID] else {
                continue
            }
            let deltaX = center.x - currentCenter.x
            let deltaY = center.y - currentCenter.y

            let mainAxisDistance: Double
            let crossAxisDistance: Double
            switch direction {
            case .up:
                mainAxisDistance = -deltaY
                crossAxisDistance = abs(deltaX)
            case .down:
                mainAxisDistance = deltaY
                crossAxisDistance = abs(deltaX)
            case .left:
                mainAxisDistance = -deltaX
                crossAxisDistance = abs(deltaY)
            case .right:
                mainAxisDistance = deltaX
                crossAxisDistance = abs(deltaY)
            }

            guard mainAxisDistance > 0 else {
                continue
            }
            let score = mainAxisDistance + (crossAxisDistance * 2.5)

            if let currentBest = bestCandidate {
                if score < currentBest.score
                    || (score == currentBest.score && areaID.rawValue < currentBest.id.rawValue)
                {
                    bestCandidate = (areaID, score)
                }
            } else {
                bestCandidate = (areaID, score)
            }
        }

        return bestCandidate?.id
    }

    private func acrossAreaDestinationAreaID(
        in graph: CanvasGraph,
        moving direction: CanvasFocusDirection,
        from focusedAreaID: CanvasAreaID
    ) -> CanvasAreaID? {
        if let directionalAreaID = nextFocusedAreaID(
            in: graph,
            moving: direction,
            from: focusedAreaID
        ) {
            return directionalAreaID
        }

        let areaCenters = areaCenterByID(in: graph)
        let candidateAreaIDs = areaCenters.keys.filter { $0 != focusedAreaID }
        guard !candidateAreaIDs.isEmpty else {
            return nil
        }

        switch direction {
        case .right:
            return candidateAreaIDs.min(by: { lhs, rhs in
                isAreaOrderedBefore(lhs, rhs, areaCenters: areaCenters)
            })
        case .left:
            return candidateAreaIDs.max(by: { lhs, rhs in
                isAreaOrderedBefore(lhs, rhs, areaCenters: areaCenters)
            })
        case .up, .down:
            return nil
        }
    }

    private func isAreaOrderedBefore(
        _ lhs: CanvasAreaID,
        _ rhs: CanvasAreaID,
        areaCenters: [CanvasAreaID: (x: Double, y: Double)]
    ) -> Bool {
        guard
            let lhsCenter = areaCenters[lhs],
            let rhsCenter = areaCenters[rhs]
        else {
            return lhs.rawValue < rhs.rawValue
        }
        if lhsCenter.x != rhsCenter.x {
            return lhsCenter.x < rhsCenter.x
        }
        if lhsCenter.y != rhsCenter.y {
            return lhsCenter.y < rhsCenter.y
        }
        return lhs.rawValue < rhs.rawValue
    }

    private func areaAnchorNodeID(
        in area: CanvasArea,
        graph: CanvasGraph,
        visibleNodeIDs: Set<CanvasNodeID>
    ) -> CanvasNodeID? {
        area.nodeIDs
            .filter { visibleNodeIDs.contains($0) && graph.nodesByID[$0] != nil }
            .sorted { lhs, rhs in
                guard let lhsNode = graph.nodesByID[lhs], let rhsNode = graph.nodesByID[rhs] else {
                    return lhs.rawValue < rhs.rawValue
                }
                if lhsNode.bounds.y != rhsNode.bounds.y {
                    return lhsNode.bounds.y < rhsNode.bounds.y
                }
                if lhsNode.bounds.x != rhsNode.bounds.x {
                    return lhsNode.bounds.x < rhsNode.bounds.x
                }
                return lhs.rawValue < rhs.rawValue
            }
            .first
    }

    private func focusedAreaID(in graph: CanvasGraph) -> CanvasAreaID? {
        switch CanvasAreaMembershipService.focusedAreaID(in: graph) {
        case .success(let areaID):
            return areaID
        case .failure:
            return nil
        }
    }

    private func nextAreaAnchorNodeID(
        area: CanvasArea,
        in graph: CanvasGraph,
        visibleNodeIDs: Set<CanvasNodeID>
    ) -> CanvasNodeID? {
        let candidateNodeIDs = area.nodeIDs
            .filter { visibleNodeIDs.contains($0) && graph.nodesByID[$0] != nil }
        guard !candidateNodeIDs.isEmpty else {
            return nil
        }

        switch area.editingMode {
        case .tree:
            let rootNodeIDs = candidateNodeIDs.filter { nodeID in
                !graph.edgesByID.values.contains { edge in
                    edge.relationType == .parentChild && edge.toNodeID == nodeID
                }
            }
            guard !rootNodeIDs.isEmpty else {
                return nil
            }
            return rootNodeIDs.min(by: { lhs, rhs in
                isCreatedEarlier(lhs, than: rhs, in: graph)
            })
        case .diagram:
            return candidateNodeIDs.min(by: { lhs, rhs in
                isCreatedEarlier(lhs, than: rhs, in: graph)
            })
        }
    }

    private func isCreatedEarlier(
        _ lhsNodeID: CanvasNodeID,
        than rhsNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> Bool {
        guard let lhsNode = graph.nodesByID[lhsNodeID], let rhsNode = graph.nodesByID[rhsNodeID] else {
            return lhsNodeID.rawValue < rhsNodeID.rawValue
        }

        let lhsCreatedOrder = nodeCreatedOrder(for: lhsNode)
        let rhsCreatedOrder = nodeCreatedOrder(for: rhsNode)
        if lhsCreatedOrder != rhsCreatedOrder {
            return lhsCreatedOrder < rhsCreatedOrder
        }
        if lhsNode.bounds.y != rhsNode.bounds.y {
            return lhsNode.bounds.y < rhsNode.bounds.y
        }
        if lhsNode.bounds.x != rhsNode.bounds.x {
            return lhsNode.bounds.x < rhsNode.bounds.x
        }
        return lhsNode.id.rawValue < rhsNode.id.rawValue
    }

    private func nodeCreatedOrder(for node: CanvasNode) -> Int {
        guard let value = node.metadata[Self.nodeCreatedOrderMetadataKey] else {
            return Int.max
        }
        return Int(value) ?? Int.max
    }

    private func updateFocusedNodeAndElement(
        in graph: CanvasGraph,
        focusedNodeID: CanvasNodeID,
        focusedElement: CanvasFocusedElement,
        selectedNodeIDs: Set<CanvasNodeID>
    ) -> CanvasMutationResult {
        guard
            graph.focusedNodeID != focusedNodeID
                || graph.focusedElement != focusedElement
                || graph.selectedNodeIDs != selectedNodeIDs
                || !graph.selectedEdgeIDs.isEmpty
        else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: graph.nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: focusedNodeID,
            focusedElement: focusedElement,
            selectedNodeIDs: selectedNodeIDs,
            selectedEdgeIDs: [],
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: true
            )
        )
    }

    private func areaCenterByID(in graph: CanvasGraph) -> [CanvasAreaID: (x: Double, y: Double)] {
        var centers: [CanvasAreaID: (x: Double, y: Double)] = [:]
        for area in graph.areasByID.values {
            let nodes = area.nodeIDs.compactMap { graph.nodesByID[$0] }
            guard let firstNode = nodes.first else {
                continue
            }
            var minX = firstNode.bounds.x
            var minY = firstNode.bounds.y
            var maxX = firstNode.bounds.x + firstNode.bounds.width
            var maxY = firstNode.bounds.y + firstNode.bounds.height
            for node in nodes {
                minX = min(minX, node.bounds.x)
                minY = min(minY, node.bounds.y)
                maxX = max(maxX, node.bounds.x + node.bounds.width)
                maxY = max(maxY, node.bounds.y + node.bounds.height)
            }
            centers[area.id] = (x: (minX + maxX) / 2, y: (minY + maxY) / 2)
        }
        return centers
    }
}
