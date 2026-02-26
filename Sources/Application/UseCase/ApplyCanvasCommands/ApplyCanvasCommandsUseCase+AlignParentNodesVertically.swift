import Domain

// Background: Users need one command that can align split areas into a readable vertical column.
// Responsibility: Translate each area as a rigid block, preserving intra-area layout.
extension ApplyCanvasCommandsUseCase {
    /// Aligns all non-empty areas to a common left edge and stacks them vertically.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - areaID: Focused area identifier resolved by command dispatch. The command still applies to all areas.
    /// - Returns: Mutation result with translated area blocks, or no-op when nothing moves.
    func alignParentNodesVertically(
        in graph: CanvasGraph,
        areaID _: CanvasAreaID
    ) -> CanvasMutationResult {
        let alignmentPlans = areaAlignmentPlans(in: graph)
        guard !alignmentPlans.isEmpty else {
            return noOpMutationResult(for: graph)
        }

        var nodesByID = graph.nodesByID
        var didTranslateAnyNode = false
        for plan in alignmentPlans {
            guard plan.dx != 0 || plan.dy != 0 else {
                continue
            }
            for nodeID in plan.nodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard let node = nodesByID[nodeID] else {
                    continue
                }
                nodesByID[nodeID] = CanvasNode(
                    id: node.id,
                    kind: node.kind,
                    text: node.text,
                    attachments: node.attachments,
                    bounds: translate(node.bounds, dx: plan.dx, dy: plan.dy),
                    metadata: node.metadata,
                    markdownStyleEnabled: node.markdownStyleEnabled
                )
                didTranslateAnyNode = true
            }
        }
        guard didTranslateAnyNode else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
            selectedNodeIDs: graph.selectedNodeIDs,
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
                needsFocusNormalization: false
            )
        )
    }

    /// Builds rigid-translation plans that align area bounds to one left column.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Ordered alignment plans. Empty when there is one or zero non-empty areas.
    private func areaAlignmentPlans(in graph: CanvasGraph) -> [AreaAlignmentPlan] {
        let snapshots = areaBoundsSnapshots(in: graph)
        guard snapshots.count > 1 else {
            return []
        }
        guard let alignedMinX = snapshots.map(\.bounds.minX).min() else {
            return []
        }

        let orderedSnapshots = snapshots.sorted { lhs, rhs in
            if lhs.bounds.minY != rhs.bounds.minY {
                return lhs.bounds.minY < rhs.bounds.minY
            }
            if lhs.bounds.minX != rhs.bounds.minX {
                return lhs.bounds.minX < rhs.bounds.minX
            }
            return lhs.areaID.rawValue < rhs.areaID.rawValue
        }

        var plans: [AreaAlignmentPlan] = []
        var nextAllowedMinY = orderedSnapshots[0].bounds.minY
        for (index, snapshot) in orderedSnapshots.enumerated() {
            let alignedMinY: Double
            if index == 0 {
                alignedMinY = snapshot.bounds.minY
            } else {
                alignedMinY = max(snapshot.bounds.minY, nextAllowedMinY)
            }
            let dx = alignedMinX - snapshot.bounds.minX
            let dy = alignedMinY - snapshot.bounds.minY
            let translatedBounds = snapshot.bounds.translated(dx: dx, dy: dy)
            nextAllowedMinY = translatedBounds.maxY + Self.areaCollisionSpacing
            plans.append(
                AreaAlignmentPlan(
                    nodeIDs: snapshot.nodeIDs,
                    dx: dx,
                    dy: dy
                )
            )
        }
        return plans
    }

    /// Collects bounds for all non-empty areas.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Bounds snapshots for areas with at least one existing node.
    private func areaBoundsSnapshots(in graph: CanvasGraph) -> [AreaBoundsSnapshot] {
        graph.areasByID.keys.sorted(by: { $0.rawValue < $1.rawValue }).compactMap { areaID in
            guard let area = graph.areasByID[areaID] else {
                return nil
            }
            guard let bounds = areaBounds(nodeIDs: area.nodeIDs, nodesByID: graph.nodesByID) else {
                return nil
            }
            return AreaBoundsSnapshot(areaID: area.id, nodeIDs: area.nodeIDs, bounds: bounds)
        }
    }

    /// Computes enclosing bounds for a node set.
    /// - Parameters:
    ///   - nodeIDs: Node identifiers in one area.
    ///   - nodesByID: Node table.
    /// - Returns: Enclosing rectangle, or `nil` when no nodes exist.
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
        for node in nodes {
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
}

extension ApplyCanvasCommandsUseCase {
    private struct AreaBoundsSnapshot {
        let areaID: CanvasAreaID
        let nodeIDs: Set<CanvasNodeID>
        let bounds: CanvasRect
    }

    private struct AreaAlignmentPlan {
        let nodeIDs: Set<CanvasNodeID>
        let dx: Double
        let dy: Double
    }
}
