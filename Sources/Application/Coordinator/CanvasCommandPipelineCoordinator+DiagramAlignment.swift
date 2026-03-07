// Background: Alignment commands need overlap resolution that does not break the chosen axis.
// Responsibility: Repack aligned diagram nodes along the orthogonal axis while keeping the anchor fixed.
import Domain

extension CanvasCommandPipelineCoordinator {
    func runDiagramAlignmentConstraintStage(
        on graph: CanvasGraph,
        constraint: CanvasDiagramAlignmentConstraint
    ) -> CanvasGraph {
        guard constraint.targetNodeIDs.count > 1 else {
            return graph
        }
        guard let fixedNode = graph.nodesByID[constraint.fixedNodeID] else {
            return graph
        }
        guard
            let area = graph.areasByID.values.first(where: { $0.nodeIDs.contains(constraint.fixedNodeID) })
        else {
            return graph
        }

        let targetNodeIDs = area.nodeIDs.intersection(constraint.targetNodeIDs)
        let targetNodes = targetNodeIDs.compactMap { graph.nodesByID[$0] }
        guard targetNodes.count > 1 else {
            return graph
        }

        var placementState = DiagramAlignmentPlacementState(
            occupiedRects: diagramAlignmentBlockerRects(
                in: graph,
                area: area,
                axis: constraint.axis,
                targetNodeIDs: targetNodeIDs,
                targetNodes: targetNodes
            ),
            updatedBoundsByNodeID: [fixedNode.id: fixedNode.bounds]
        )
        let sortedTargetNodeIDs = sortedAlignedNodeIDs(
            axis: constraint.axis,
            nodes: targetNodes
        )
        guard let fixedIndex = sortedTargetNodeIDs.firstIndex(of: constraint.fixedNodeID) else {
            return graph
        }

        placementState.occupiedRects.append(canvasRect(from: fixedNode.bounds))
        placeAlignedNodes(
            in: graph,
            request: DiagramAlignmentPlacementRequest(
                axis: constraint.axis,
                minimumSpacing: constraint.minimumSpacing,
                nodeIDs: Array(sortedTargetNodeIDs.dropFirst(fixedIndex + 1)),
                direction: .forward
            ),
            state: &placementState
        )
        placeAlignedNodes(
            in: graph,
            request: DiagramAlignmentPlacementRequest(
                axis: constraint.axis,
                minimumSpacing: constraint.minimumSpacing,
                nodeIDs: Array(sortedTargetNodeIDs.prefix(fixedIndex).reversed()),
                direction: .backward
            ),
            state: &placementState
        )

        return graphWithUpdatedNodeBounds(
            in: graph,
            updatedBoundsByNodeID: placementState.updatedBoundsByNodeID
        )
    }
}

extension CanvasCommandPipelineCoordinator {
    private enum AlignmentResolutionDirection {
        case forward
        case backward
    }

    private struct DiagramAlignmentPlacementState {
        var occupiedRects: [CanvasRect]
        var updatedBoundsByNodeID: [CanvasNodeID: CanvasBounds]
    }

    private struct DiagramAlignmentPlacementRequest {
        let axis: CanvasNodeAlignmentAxis
        let minimumSpacing: Double
        let nodeIDs: [CanvasNodeID]
        let direction: AlignmentResolutionDirection
    }

    private func placeAlignedNodes(
        in graph: CanvasGraph,
        request: DiagramAlignmentPlacementRequest,
        state: inout DiagramAlignmentPlacementState
    ) {
        for nodeID in request.nodeIDs {
            guard let node = graph.nodesByID[nodeID] else {
                continue
            }
            let resolvedBounds = resolvedAlignedBounds(
                for: node.bounds,
                axis: request.axis,
                direction: request.direction,
                occupiedRects: state.occupiedRects,
                minimumSpacing: request.minimumSpacing
            )
            state.occupiedRects.append(canvasRect(from: resolvedBounds))
            state.updatedBoundsByNodeID[nodeID] = resolvedBounds
        }
    }

    private func diagramAlignmentBlockerRects(
        in graph: CanvasGraph,
        area: CanvasArea,
        axis: CanvasNodeAlignmentAxis,
        targetNodeIDs: Set<CanvasNodeID>,
        targetNodes: [CanvasNode]
    ) -> [CanvasRect] {
        let alignmentBand = makeAlignmentBand(axis: axis, nodes: targetNodes)
        return area.nodeIDs
            .subtracting(targetNodeIDs)
            .compactMap { graph.nodesByID[$0]?.bounds }
            .filter { blockerBounds in
                alignmentBandIntersects(
                    axis: axis,
                    band: alignmentBand,
                    bounds: blockerBounds
                )
            }
            .map(canvasRect(from:))
    }

    private func sortedAlignedNodeIDs(
        axis: CanvasNodeAlignmentAxis,
        nodes: [CanvasNode]
    ) -> [CanvasNodeID] {
        nodes
            .sorted { lhs, rhs in
                nodeAlignmentSortValue(axis: axis, node: lhs) < nodeAlignmentSortValue(axis: axis, node: rhs)
            }
            .map(\.id)
    }

    private func makeAlignmentBand(
        axis: CanvasNodeAlignmentAxis,
        nodes: [CanvasNode]
    ) -> ClosedRange<Double> {
        let ranges = nodes.map { node in
            switch axis {
            case .horizontal:
                node.bounds.y...(node.bounds.y + node.bounds.height)
            case .vertical:
                node.bounds.x...(node.bounds.x + node.bounds.width)
            }
        }
        guard let firstRange = ranges.first else {
            return 0...0
        }
        let minimum = ranges.reduce(firstRange.lowerBound) { min($0, $1.lowerBound) }
        let maximum = ranges.reduce(firstRange.upperBound) { max($0, $1.upperBound) }
        return minimum...maximum
    }

    private func alignmentBandIntersects(
        axis: CanvasNodeAlignmentAxis,
        band: ClosedRange<Double>,
        bounds: CanvasBounds
    ) -> Bool {
        switch axis {
        case .horizontal:
            return bounds.y < band.upperBound && (bounds.y + bounds.height) > band.lowerBound
        case .vertical:
            return bounds.x < band.upperBound && (bounds.x + bounds.width) > band.lowerBound
        }
    }

    private func nodeAlignmentSortValue(
        axis: CanvasNodeAlignmentAxis,
        node: CanvasNode
    ) -> (Double, String) {
        switch axis {
        case .horizontal:
            return (node.bounds.x + (node.bounds.width / 2), node.id.rawValue)
        case .vertical:
            return (node.bounds.y + (node.bounds.height / 2), node.id.rawValue)
        }
    }

    private func resolvedAlignedBounds(
        for bounds: CanvasBounds,
        axis: CanvasNodeAlignmentAxis,
        direction: AlignmentResolutionDirection,
        occupiedRects: [CanvasRect],
        minimumSpacing: Double
    ) -> CanvasBounds {
        var candidate = canvasRect(from: bounds)
        while let overlappingRect = firstOverlappingAlignedRect(
            candidate,
            occupiedRects: occupiedRects,
            minimumSpacing: minimumSpacing
        ) {
            switch (axis, direction) {
            case (.horizontal, .forward):
                candidate = candidate.translated(
                    dx: (overlappingRect.maxX + minimumSpacing) - candidate.minX,
                    dy: 0
                )
            case (.horizontal, .backward):
                candidate = candidate.translated(
                    dx: (overlappingRect.minX - minimumSpacing) - candidate.maxX,
                    dy: 0
                )
            case (.vertical, .forward):
                candidate = candidate.translated(
                    dx: 0,
                    dy: (overlappingRect.maxY + minimumSpacing) - candidate.minY
                )
            case (.vertical, .backward):
                candidate = candidate.translated(
                    dx: 0,
                    dy: (overlappingRect.minY - minimumSpacing) - candidate.maxY
                )
            }
        }
        return CanvasBounds(
            x: candidate.minX,
            y: candidate.minY,
            width: candidate.width,
            height: candidate.height
        )
    }

    private func firstOverlappingAlignedRect(
        _ candidate: CanvasRect,
        occupiedRects: [CanvasRect],
        minimumSpacing: Double
    ) -> CanvasRect? {
        let expandedCandidate = candidate.expanded(
            horizontal: minimumSpacing / 2,
            vertical: minimumSpacing / 2
        )
        return occupiedRects.first { occupiedRect in
            expandedCandidate.intersects(
                occupiedRect.expanded(
                    horizontal: minimumSpacing / 2,
                    vertical: minimumSpacing / 2
                )
            )
        }
    }

    private func canvasRect(from bounds: CanvasBounds) -> CanvasRect {
        CanvasRect(
            minX: bounds.x,
            minY: bounds.y,
            width: bounds.width,
            height: bounds.height
        )
    }

    private func graphWithUpdatedNodeBounds(
        in graph: CanvasGraph,
        updatedBoundsByNodeID: [CanvasNodeID: CanvasBounds]
    ) -> CanvasGraph {
        guard !updatedBoundsByNodeID.isEmpty else {
            return graph
        }

        var nodesByID = graph.nodesByID
        for nodeID in updatedBoundsByNodeID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let node = nodesByID[nodeID] else {
                continue
            }
            guard let bounds = updatedBoundsByNodeID[nodeID] else {
                continue
            }
            nodesByID[nodeID] = CanvasNode(
                id: node.id,
                kind: node.kind,
                text: node.text,
                attachments: node.attachments,
                bounds: bounds,
                metadata: node.metadata,
                markdownStyleEnabled: node.markdownStyleEnabled
            )
        }
        return CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            focusedElement: graph.focusedElement,
            selectedNodeIDs: graph.selectedNodeIDs,
            selectedEdgeIDs: graph.selectedEdgeIDs,
            collapsedRootNodeIDs: graph.collapsedRootNodeIDs,
            areasByID: graph.areasByID
        )
    }
}
