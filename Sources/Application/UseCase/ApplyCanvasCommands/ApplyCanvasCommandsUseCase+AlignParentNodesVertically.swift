import Domain

// Background: Users need a fast way to visually organize root-level nodes in one area.
// Responsibility: Align parent nodes to the leftmost x-position within the focused area.
extension ApplyCanvasCommandsUseCase {
    /// Aligns parent nodes in one area to a single vertical line using the leftmost parent node as anchor.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - areaID: Area identifier whose parent nodes are aligned.
    /// - Returns: Mutation result with updated node bounds, or no-op when alignment has no effect.
    func alignParentNodesVertically(
        in graph: CanvasGraph,
        areaID: CanvasAreaID
    ) -> CanvasMutationResult {
        guard let area = graph.areasByID[areaID] else {
            return noOpMutationResult(for: graph)
        }
        let parentNodeIDs = parentNodeIDs(in: area, graph: graph)
        guard !parentNodeIDs.isEmpty else {
            return noOpMutationResult(for: graph)
        }
        let memberNodeIDs = area.nodeIDs
        var nodesByID = graph.nodesByID
        var didTranslateAnyNode = applyParentSubtreeHorizontalAlignment(
            parentNodeIDs: parentNodeIDs,
            memberNodeIDs: memberNodeIDs,
            graph: graph,
            nodesByID: &nodesByID
        )

        let movedParentNodeIDs = resolveParentSubtreeVerticalOverlaps(
            parentNodeIDs: parentNodeIDs,
            memberNodeIDs: memberNodeIDs,
            graph: graph,
            nodesByID: &nodesByID
        )
        if !movedParentNodeIDs.isEmpty {
            didTranslateAnyNode = true
        }

        guard didTranslateAnyNode else {
            return noOpMutationResult(for: graph)
        }

        let nextGraph = CanvasGraph(
            nodesByID: nodesByID,
            edgesByID: graph.edgesByID,
            focusedNodeID: graph.focusedNodeID,
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

    /// Aligns each parent-rooted subtree to the leftmost parent x-position.
    /// - Parameters:
    ///   - parentNodeIDs: Parent node identifiers.
    ///   - memberNodeIDs: Area member node identifiers.
    ///   - graph: Current graph snapshot.
    ///   - nodesByID: Mutable node table.
    /// - Returns: `true` when at least one node moved horizontally.
    private func applyParentSubtreeHorizontalAlignment(
        parentNodeIDs: Set<CanvasNodeID>,
        memberNodeIDs: Set<CanvasNodeID>,
        graph: CanvasGraph,
        nodesByID: inout [CanvasNodeID: CanvasNode]
    ) -> Bool {
        let parentNodes = parentNodeIDs.compactMap { graph.nodesByID[$0] }
        guard let leftmostX = parentNodes.map(\.bounds.x).min() else {
            return false
        }
        let horizontalDeltaByParentID: [CanvasNodeID: Double] = Dictionary(
            uniqueKeysWithValues: parentNodes.compactMap { parentNode in
                let dx = leftmostX - parentNode.bounds.x
                guard dx != 0 else {
                    return nil
                }
                return (parentNode.id, dx)
            }
        )

        var didTranslateAnyNode = false
        var translatedNodeIDs: Set<CanvasNodeID> = []
        for nodeID in parentNodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let dx = horizontalDeltaByParentID[nodeID] else {
                continue
            }
            let subtreeNodeIDs = subtreeNodeIDs(
                rootedAt: nodeID,
                in: graph,
                memberNodeIDs: memberNodeIDs
            )
            for subtreeNodeID in subtreeNodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
                guard !translatedNodeIDs.contains(subtreeNodeID) else {
                    continue
                }
                guard let node = nodesByID[subtreeNodeID] else {
                    continue
                }
                nodesByID[subtreeNodeID] = CanvasNode(
                    id: node.id,
                    kind: node.kind,
                    text: node.text,
                    bounds: CanvasBounds(
                        x: node.bounds.x + dx,
                        y: node.bounds.y,
                        width: node.bounds.width,
                        height: node.bounds.height
                    ),
                    metadata: node.metadata,
                    markdownStyleEnabled: node.markdownStyleEnabled
                )
                translatedNodeIDs.insert(subtreeNodeID)
                didTranslateAnyNode = true
            }
        }

        return didTranslateAnyNode
    }

    /// Resolves overlap among parent-rooted subtrees while preserving horizontal alignment.
    /// - Parameters:
    ///   - parentNodeIDs: Parent node identifiers to process.
    ///   - memberNodeIDs: Area member node identifiers.
    ///   - graph: Current graph snapshot used for subtree traversal.
    ///   - nodesByID: Mutable node table.
    /// - Returns: Parent node identifiers whose subtree moved on Y axis.
    private func resolveParentSubtreeVerticalOverlaps(
        parentNodeIDs: Set<CanvasNodeID>,
        memberNodeIDs: Set<CanvasNodeID>,
        graph: CanvasGraph,
        nodesByID: inout [CanvasNodeID: CanvasNode]
    ) -> Set<CanvasNodeID> {
        let orderedParentNodeIDs = parentNodeIDs.sorted { lhs, rhs in
            guard let lhsNode = nodesByID[lhs], let rhsNode = nodesByID[rhs] else {
                return lhs.rawValue < rhs.rawValue
            }
            if lhsNode.bounds.y == rhsNode.bounds.y {
                return lhs.rawValue < rhs.rawValue
            }
            return lhsNode.bounds.y < rhsNode.bounds.y
        }

        var movedParentNodeIDs: Set<CanvasNodeID> = []
        var placedSubtreeBounds: [CanvasRect] = []

        for parentNodeID in orderedParentNodeIDs {
            let subtreeNodeIDs = subtreeNodeIDs(
                rootedAt: parentNodeID,
                in: graph,
                memberNodeIDs: memberNodeIDs
            )
            guard
                let currentSubtreeBounds = subtreeBounds(
                    for: subtreeNodeIDs,
                    nodesByID: nodesByID
                )
            else {
                continue
            }

            let requiredMinY = requiredSubtreeMinY(
                for: currentSubtreeBounds,
                against: placedSubtreeBounds,
                minimumSpacing: Self.areaCollisionSpacing
            )
            let dy = requiredMinY - currentSubtreeBounds.minY
            if dy > 0 {
                for subtreeNodeID in subtreeNodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
                    guard let node = nodesByID[subtreeNodeID] else {
                        continue
                    }
                    nodesByID[subtreeNodeID] = CanvasNode(
                        id: node.id,
                        kind: node.kind,
                        text: node.text,
                        bounds: CanvasBounds(
                            x: node.bounds.x,
                            y: node.bounds.y + dy,
                            width: node.bounds.width,
                            height: node.bounds.height
                        ),
                        metadata: node.metadata,
                        markdownStyleEnabled: node.markdownStyleEnabled
                    )
                }
                movedParentNodeIDs.insert(parentNodeID)
            }

            if let nextBounds = subtreeBounds(for: subtreeNodeIDs, nodesByID: nodesByID) {
                placedSubtreeBounds.append(nextBounds)
            }
        }

        return movedParentNodeIDs
    }

    /// Computes subtree bounds from current nodes.
    /// - Parameters:
    ///   - nodeIDs: Target node identifiers.
    ///   - nodesByID: Node table.
    /// - Returns: Bounds that enclose all target nodes.
    private func subtreeBounds(
        for nodeIDs: Set<CanvasNodeID>,
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

    /// Calculates required minimum Y to avoid collision with already placed subtrees.
    /// - Parameters:
    ///   - candidate: Candidate subtree bounds.
    ///   - placedBounds: Bounds already fixed in order.
    ///   - minimumSpacing: Required spacing between two subtrees.
    /// - Returns: Minimum allowed top Y.
    private func requiredSubtreeMinY(
        for candidate: CanvasRect,
        against placedBounds: [CanvasRect],
        minimumSpacing: Double
    ) -> Double {
        var minY = candidate.minY
        for placed in placedBounds {
            let horizontalCollision =
                candidate.minX < (placed.maxX + minimumSpacing)
                && candidate.maxX > (placed.minX - minimumSpacing)
            guard horizontalCollision else {
                continue
            }
            minY = max(minY, placed.maxY + minimumSpacing)
        }
        return minY
    }
}

extension ApplyCanvasCommandsUseCase {
    /// Returns parent nodes inside one area (nodes without incoming parent-child edge from area members).
    /// - Parameters:
    ///   - area: Area that provides the node membership boundary.
    ///   - graph: Current canvas graph.
    /// - Returns: Parent node identifiers in the area.
    private func parentNodeIDs(in area: CanvasArea, graph: CanvasGraph) -> Set<CanvasNodeID> {
        let memberNodeIDs = area.nodeIDs
        let childNodeIDs = Set(
            graph.edgesByID.values
                .filter {
                    $0.relationType == .parentChild
                        && memberNodeIDs.contains($0.fromNodeID)
                        && memberNodeIDs.contains($0.toNodeID)
                }
                .map(\.toNodeID)
        )
        return memberNodeIDs.subtracting(childNodeIDs)
    }

    /// Returns one root subtree node set within area members.
    /// - Parameters:
    ///   - rootNodeID: Root parent node identifier.
    ///   - graph: Current canvas graph.
    ///   - memberNodeIDs: Area member node identifiers.
    /// - Returns: Root and descendants reachable by parent-child edges constrained in one area.
    private func subtreeNodeIDs(
        rootedAt rootNodeID: CanvasNodeID,
        in graph: CanvasGraph,
        memberNodeIDs: Set<CanvasNodeID>
    ) -> Set<CanvasNodeID> {
        var visited: Set<CanvasNodeID> = [rootNodeID]
        var queue: [CanvasNodeID] = [rootNodeID]

        while !queue.isEmpty {
            let currentNodeID = queue.removeFirst()
            for edge in graph.edgesByID.values {
                guard edge.relationType == .parentChild else {
                    continue
                }
                guard edge.fromNodeID == currentNodeID else {
                    continue
                }
                guard memberNodeIDs.contains(edge.fromNodeID), memberNodeIDs.contains(edge.toNodeID) else {
                    continue
                }
                guard !visited.contains(edge.toNodeID) else {
                    continue
                }
                visited.insert(edge.toNodeID)
                queue.append(edge.toNodeID)
            }
        }

        return visited
    }
}
