import Domain

// Background: Area target operations should move an entire area as one block while preserving intra-area layout.
// Responsibility: Translate all nodes in one area and request area-overlap resolution.
extension ApplyCanvasCommandsUseCase {
    private static let areaMoveHorizontalStep: Double = CanvasDefaultNodeDistance.diagramHorizontal
    private static let areaMoveVerticalStep: Double = CanvasDefaultNodeDistance.diagramVertical
    private static let areaMoveCollisionSpacing: Double = 32

    /// Moves the focused area in one cardinal direction and lets pipeline area layout resolve collisions.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - areaID: Area to move.
    ///   - direction: Cardinal direction.
    /// - Returns: Mutation result with translated nodes, or no-op when movement is not possible.
    func moveArea(
        in graph: CanvasGraph,
        areaID: CanvasAreaID,
        direction: CanvasFocusDirection
    ) -> CanvasMutationResult {
        guard let targetNodeIDs = movableAreaNodeIDs(in: graph, areaID: areaID) else {
            return noOpMutationResult(for: graph)
        }

        let translation = areaMoveTranslation(for: direction)
        guard translation.dx != 0 || translation.dy != 0 else {
            return noOpMutationResult(for: graph)
        }

        guard
            let graphAfterMove = translatedAreaGraph(
                from: graph,
                targetNodeIDs: targetNodeIDs,
                translation: translation
            )
        else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = resolveAreaOverlapsAfterAreaMove(
            in: graphAfterMove,
            movedAreaID: areaID
        )

        let didMutateGraph = nextGraph != graph
        guard didMutateGraph else {
            return noOpMutationResult(for: graph)
        }
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: didMutateGraph,
                needsTreeLayout: false,
                needsAreaLayout: false,
                needsFocusNormalization: false
            )
        )
    }

    private func movableAreaNodeIDs(
        in graph: CanvasGraph,
        areaID: CanvasAreaID
    ) -> [CanvasNodeID]? {
        guard let area = graph.areasByID[areaID] else {
            return nil
        }
        let targetNodeIDs = area.nodeIDs
            .filter { graph.nodesByID[$0] != nil }
            .sorted(by: { $0.rawValue < $1.rawValue })
        return targetNodeIDs.isEmpty ? nil : targetNodeIDs
    }

    private func translatedAreaGraph(
        from graph: CanvasGraph,
        targetNodeIDs: [CanvasNodeID],
        translation: (dx: Double, dy: Double)
    ) -> CanvasGraph? {
        var nodesByID = graph.nodesByID
        var didTranslateAnyNode = false
        for nodeID in targetNodeIDs {
            guard let node = nodesByID[nodeID] else {
                continue
            }
            nodesByID[nodeID] = translatedAreaNode(node, translation: translation)
            didTranslateAnyNode = true
        }
        guard didTranslateAnyNode else {
            return nil
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

    private func translatedAreaNode(
        _ node: CanvasNode,
        translation: (dx: Double, dy: Double)
    ) -> CanvasNode {
        CanvasNode(
            id: node.id,
            kind: node.kind,
            text: node.text,
            attachments: node.attachments,
            bounds: CanvasBounds(
                x: node.bounds.x + translation.dx,
                y: node.bounds.y + translation.dy,
                width: node.bounds.width,
                height: node.bounds.height
            ),
            metadata: node.metadata,
            markdownStyleEnabled: node.markdownStyleEnabled
        )
    }

    private func areaMoveTranslation(
        for direction: CanvasFocusDirection
    ) -> (dx: Double, dy: Double) {
        switch direction {
        case .up:
            return (0, -Self.areaMoveVerticalStep)
        case .down:
            return (0, Self.areaMoveVerticalStep)
        case .left:
            return (-Self.areaMoveHorizontalStep, 0)
        case .right:
            return (Self.areaMoveHorizontalStep, 0)
        }
    }

    private func resolveAreaOverlapsAfterAreaMove(
        in graph: CanvasGraph,
        movedAreaID: CanvasAreaID
    ) -> CanvasGraph {
        let snapshots = areaOutlineSnapshots(in: graph)
        guard snapshots.count > 1 else {
            return graph
        }
        let snapshotsByLayoutID = Dictionary(
            uniqueKeysWithValues: snapshots.map { ($0.layoutArea.id, $0) }
        )
        let seedLayoutAreaID = CanvasNodeID(rawValue: "area-\(movedAreaID.rawValue)")
        let translationsByLayoutAreaID = CanvasAreaLayoutService.resolveOverlaps(
            areas: snapshots.map(\.layoutArea),
            seedAreaID: seedLayoutAreaID,
            minimumSpacing: Self.areaMoveCollisionSpacing
        )
        guard !translationsByLayoutAreaID.isEmpty else {
            return graph
        }

        var nodesByID = graph.nodesByID
        for layoutAreaID in translationsByLayoutAreaID.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let translation = translationsByLayoutAreaID[layoutAreaID] else {
                continue
            }
            guard let snapshot = snapshotsByLayoutID[layoutAreaID] else {
                continue
            }
            guard translation.dx != 0 || translation.dy != 0 else {
                continue
            }
            for nodeID in snapshot.nodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let node = nodesByID[nodeID] else {
                    continue
                }
                nodesByID[nodeID] = CanvasNode(
                    id: node.id,
                    kind: node.kind,
                    text: node.text,
                    attachments: node.attachments,
                    bounds: CanvasBounds(
                        x: node.bounds.x + translation.dx,
                        y: node.bounds.y + translation.dy,
                        width: node.bounds.width,
                        height: node.bounds.height
                    ),
                    metadata: node.metadata,
                    markdownStyleEnabled: node.markdownStyleEnabled
                )
            }
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

    private func areaOutlineSnapshots(in graph: CanvasGraph) -> [AreaOutlineSnapshot] {
        graph.areasByID.values
            .sorted(by: { $0.id.rawValue < $1.id.rawValue })
            .compactMap { area in
                let nodeIDs = area.nodeIDs
                    .filter { graph.nodesByID[$0] != nil }
                guard let bounds = areaBounds(nodeIDs: nodeIDs, nodesByID: graph.nodesByID) else {
                    return nil
                }
                let layoutAreaID = CanvasNodeID(rawValue: "area-\(area.id.rawValue)")
                return AreaOutlineSnapshot(
                    areaID: area.id,
                    nodeIDs: nodeIDs,
                    layoutArea: CanvasNodeArea(
                        id: layoutAreaID,
                        nodeIDs: nodeIDs,
                        bounds: bounds,
                        shape: .rectangle
                    )
                )
            }
    }

    private func areaBounds(
        nodeIDs: Set<CanvasNodeID>,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> CanvasRect? {
        let nodes = nodeIDs.compactMap { nodesByID[$0] }
        guard let firstNode = nodes.first else {
            return nil
        }
        var minX = firstNode.bounds.x
        var minY = firstNode.bounds.y
        var maxX = firstNode.bounds.x + firstNode.bounds.width
        var maxY = firstNode.bounds.y + firstNode.bounds.height
        for node in nodes.dropFirst() {
            minX = min(minX, node.bounds.x)
            minY = min(minY, node.bounds.y)
            maxX = max(maxX, node.bounds.x + node.bounds.width)
            maxY = max(maxY, node.bounds.y + node.bounds.height)
        }
        return CanvasRect(minX: minX, minY: minY, width: maxX - minX, height: maxY - minY)
    }
}

extension ApplyCanvasCommandsUseCase {
    private struct AreaOutlineSnapshot {
        let areaID: CanvasAreaID
        let nodeIDs: Set<CanvasNodeID>
        let layoutArea: CanvasNodeArea
    }
}
