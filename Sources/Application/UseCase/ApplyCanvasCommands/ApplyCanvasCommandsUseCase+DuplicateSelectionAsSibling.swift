import Domain
import Foundation

// Background: Duplicate command must clone focused/selected tree nodes while preserving tree structure.
// Responsibility: Duplicate selected subtree roots as siblings under their current parents in tree areas.
extension ApplyCanvasCommandsUseCase {
    private struct DuplicateTraversalState {
        var insertedNodeIDs: Set<CanvasNodeID>
        var activeSourcePathNodeIDs: Set<CanvasNodeID>
        var duplicatedNodeIDBySourceNodeID: [CanvasNodeID: CanvasNodeID]
    }

    /// Duplicates selected nodes (or focused node when selection is empty) as sibling subtrees.
    /// - Parameters:
    ///   - graph: Current canvas graph snapshot.
    ///   - resolvedAreaID: Area resolved for command dispatch.
    /// - Returns: Mutation result focused on first duplicated root and selected duplicated roots.
    /// - Throws: Propagates graph and area mutation failures.
    func duplicateSelectionAsSibling(
        in graph: CanvasGraph,
        resolvedAreaID: CanvasAreaID
    ) throws -> CanvasMutationResult {
        let sourceRootNodeIDs = duplicateSourceRootNodeIDs(in: graph, resolvedAreaID: resolvedAreaID)
        guard !sourceRootNodeIDs.isEmpty else {
            return noOpMutationResult(for: graph)
        }

        let duplicationResult = try duplicateRoots(
            sourceRootNodeIDs: sourceRootNodeIDs,
            sourceGraph: graph
        )

        guard !duplicationResult.duplicatedRootNodeIDs.isEmpty else {
            return noOpMutationResult(for: graph)
        }

        let graphAfterAreaAssign = try CanvasAreaMembershipService.assign(
            nodeIDs: duplicationResult.insertedNodeIDs,
            to: resolvedAreaID,
            in: duplicationResult.graphAfterMutation
        ).get()
        let nextGraph = CanvasGraph(
            nodesByID: graphAfterAreaAssign.nodesByID,
            edgesByID: graphAfterAreaAssign.edgesByID,
            focusedNodeID: duplicationResult.duplicatedRootNodeIDs.first,
            selectedNodeIDs: Set(duplicationResult.duplicatedRootNodeIDs),
            collapsedRootNodeIDs: graphAfterAreaAssign.collapsedRootNodeIDs,
            areasByID: graphAfterAreaAssign.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: duplicationResult.duplicatedRootNodeIDs.first
        )
    }
}

extension ApplyCanvasCommandsUseCase {
    private struct DuplicateRootsResult {
        let graphAfterMutation: CanvasGraph
        let duplicatedRootNodeIDs: [CanvasNodeID]
        let insertedNodeIDs: Set<CanvasNodeID>
    }

    /// Duplicates each source root and returns inserted node bookkeeping.
    private func duplicateRoots(
        sourceRootNodeIDs: [CanvasNodeID],
        sourceGraph: CanvasGraph
    ) throws -> DuplicateRootsResult {
        var graphAfterMutation = sourceGraph
        var duplicatedRootNodeIDs: [CanvasNodeID] = []
        var insertedNodeIDs: Set<CanvasNodeID> = []

        for sourceRootNodeID in sourceRootNodeIDs {
            let rootDuplicationResult = try duplicateSingleRoot(
                sourceRootNodeID: sourceRootNodeID,
                sourceGraph: sourceGraph,
                into: graphAfterMutation
            )
            guard let rootDuplicationResult else {
                continue
            }
            graphAfterMutation = rootDuplicationResult.graphAfterMutation
            duplicatedRootNodeIDs.append(rootDuplicationResult.duplicatedRootNodeID)
            insertedNodeIDs.formUnion(rootDuplicationResult.insertedNodeIDs)
        }

        return DuplicateRootsResult(
            graphAfterMutation: graphAfterMutation,
            duplicatedRootNodeIDs: duplicatedRootNodeIDs,
            insertedNodeIDs: insertedNodeIDs
        )
    }

    private struct DuplicateSingleRootResult {
        let graphAfterMutation: CanvasGraph
        let duplicatedRootNodeID: CanvasNodeID
        let insertedNodeIDs: Set<CanvasNodeID>
    }

    /// Duplicates one source root subtree as sibling under the same parent.
    private func duplicateSingleRoot(
        sourceRootNodeID: CanvasNodeID,
        sourceGraph: CanvasGraph,
        into graph: CanvasGraph
    ) throws -> DuplicateSingleRootResult? {
        guard
            let sourceRootNode = sourceGraph.nodesByID[sourceRootNodeID],
            let parentID = parentNodeID(of: sourceRootNodeID, in: sourceGraph),
            sourceGraph.nodesByID[parentID] != nil
        else {
            return nil
        }

        let siblingInsertionBounds = makeSiblingNodeBounds(
            in: graph,
            parentID: parentID,
            focusedNode: sourceRootNode,
            position: .below
        )
        let duplicateBounds = CanvasBounds(
            x: siblingInsertionBounds.x,
            y: siblingInsertionBounds.y,
            width: sourceRootNode.bounds.width,
            height: sourceRootNode.bounds.height
        )
        let duplicateRootNode = makeDuplicatedNode(from: sourceRootNode, bounds: duplicateBounds)
        var graphAfterMutation = try CanvasGraphCRUDService.createNode(duplicateRootNode, in: graph).get()
        graphAfterMutation = normalizeParentChildOrder(for: parentID, in: graphAfterMutation)
        let rootOrder = duplicateRootInsertionOrder(
            parentID: parentID,
            sourceRootNodeID: sourceRootNodeID,
            graph: graphAfterMutation
        )
        graphAfterMutation = shiftParentChildOrder(
            for: parentID,
            atOrAfter: rootOrder,
            by: 1,
            in: graphAfterMutation
        )
        graphAfterMutation = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentID, to: duplicateRootNode.id, order: rootOrder),
            in: graphAfterMutation
        ).get()
        var traversalState = DuplicateTraversalState(
            insertedNodeIDs: [duplicateRootNode.id],
            activeSourcePathNodeIDs: [],
            duplicatedNodeIDBySourceNodeID: [sourceRootNodeID: duplicateRootNode.id]
        )
        graphAfterMutation = try duplicateChildSubtrees(
            fromSourceNodeID: sourceRootNodeID,
            toDuplicatedParentNodeID: duplicateRootNode.id,
            sourceGraph: sourceGraph,
            into: graphAfterMutation,
            traversalState: &traversalState
        )
        return DuplicateSingleRootResult(
            graphAfterMutation: graphAfterMutation,
            duplicatedRootNodeID: duplicateRootNode.id,
            insertedNodeIDs: traversalState.insertedNodeIDs
        )
    }

    /// Computes duplication source roots by prioritizing selection over focused node.
    private func duplicateSourceRootNodeIDs(
        in graph: CanvasGraph,
        resolvedAreaID: CanvasAreaID
    ) -> [CanvasNodeID] {
        let sourceNodeIDs: Set<CanvasNodeID>
        if graph.selectedNodeIDs.isEmpty {
            guard let focusedNodeID = graph.focusedNodeID, graph.nodesByID[focusedNodeID] != nil else {
                return []
            }
            sourceNodeIDs = [focusedNodeID]
        } else {
            sourceNodeIDs = Set(
                graph.selectedNodeIDs.filter { selectedNodeID in
                    graph.nodesByID[selectedNodeID] != nil
                }
            )
        }

        let nodeIDsInResolvedArea = sourceNodeIDs.filter { sourceNodeID in
            switch CanvasAreaMembershipService.areaID(containing: sourceNodeID, in: graph) {
            case .success(let areaID):
                return areaID == resolvedAreaID
            case .failure:
                return false
            }
        }
        let sourceRootNodeIDs = nodeIDsInResolvedArea.filter { sourceNodeID in
            !hasAncestor(in: nodeIDsInResolvedArea, for: sourceNodeID, graph: graph)
        }
        return sourceRootNodeIDs.sorted { lhsID, rhsID in
            isNodeAboveForDuplicate(lhsID, rhsID, graph: graph)
        }
    }

    /// Returns true when any ancestor of the node is included in duplication sources.
    private func hasAncestor(
        in sourceNodeIDs: Set<CanvasNodeID>,
        for nodeID: CanvasNodeID,
        graph: CanvasGraph
    ) -> Bool {
        var currentNodeID = nodeID
        var visitedAncestorNodeIDs: Set<CanvasNodeID> = [nodeID]
        while let parentID = parentNodeID(of: currentNodeID, in: graph) {
            if sourceNodeIDs.contains(parentID) {
                return true
            }
            guard !visitedAncestorNodeIDs.contains(parentID) else {
                return false
            }
            visitedAncestorNodeIDs.insert(parentID)
            currentNodeID = parentID
        }
        return false
    }

    /// Provides deterministic ordering for duplication roots.
    private func isNodeAboveForDuplicate(
        _ lhsID: CanvasNodeID,
        _ rhsID: CanvasNodeID,
        graph: CanvasGraph
    ) -> Bool {
        guard let lhs = graph.nodesByID[lhsID], let rhs = graph.nodesByID[rhsID] else {
            return lhsID.rawValue < rhsID.rawValue
        }
        if lhs.bounds.y == rhs.bounds.y {
            if lhs.bounds.x == rhs.bounds.x {
                return lhs.id.rawValue < rhs.id.rawValue
            }
            return lhs.bounds.x < rhs.bounds.x
        }
        return lhs.bounds.y < rhs.bounds.y
    }

    /// Creates a duplicated node with copied content and new identifier.
    private func makeDuplicatedNode(from sourceNode: CanvasNode, bounds: CanvasBounds) -> CanvasNode {
        CanvasNode(
            id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
            kind: sourceNode.kind,
            text: sourceNode.text,
            attachments: sourceNode.attachments,
            bounds: bounds,
            metadata: sourceNode.metadata,
            markdownStyleEnabled: sourceNode.markdownStyleEnabled
        )
    }

    /// Duplicates all children of a source node under the duplicated parent recursively.
    private func duplicateChildSubtrees(
        fromSourceNodeID sourceNodeID: CanvasNodeID,
        toDuplicatedParentNodeID duplicatedParentNodeID: CanvasNodeID,
        sourceGraph: CanvasGraph,
        into graph: CanvasGraph,
        traversalState: inout DuplicateTraversalState
    ) throws -> CanvasGraph {
        var nextGraph = graph
        traversalState.activeSourcePathNodeIDs.insert(sourceNodeID)
        defer {
            traversalState.activeSourcePathNodeIDs.remove(sourceNodeID)
        }
        let sourceChildren = childNodes(of: sourceNodeID, in: sourceGraph)

        for sourceChildNode in sourceChildren {
            if let duplicatedSourceChildNodeID = traversalState.duplicatedNodeIDBySourceNodeID[sourceChildNode.id] {
                guard !traversalState.activeSourcePathNodeIDs.contains(sourceChildNode.id) else {
                    continue
                }
                nextGraph = try createParentChildEdgeIfNeeded(
                    from: duplicatedParentNodeID,
                    to: duplicatedSourceChildNodeID,
                    in: nextGraph
                )
                continue
            }

            let duplicatedChildNode = makeDuplicatedNode(
                from: sourceChildNode,
                bounds: sourceChildNode.bounds
            )
            nextGraph = try CanvasGraphCRUDService.createNode(duplicatedChildNode, in: nextGraph).get()
            traversalState.duplicatedNodeIDBySourceNodeID[sourceChildNode.id] = duplicatedChildNode.id
            nextGraph = try createParentChildEdgeIfNeeded(
                from: duplicatedParentNodeID,
                to: duplicatedChildNode.id,
                in: nextGraph
            )
            traversalState.insertedNodeIDs.insert(duplicatedChildNode.id)
            nextGraph = try duplicateChildSubtrees(
                fromSourceNodeID: sourceChildNode.id,
                toDuplicatedParentNodeID: duplicatedChildNode.id,
                sourceGraph: sourceGraph,
                into: nextGraph,
                traversalState: &traversalState
            )
        }
        return nextGraph
    }

    /// Creates one parent-child edge if the relation does not exist already.
    private func createParentChildEdgeIfNeeded(
        from parentNodeID: CanvasNodeID,
        to childNodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) throws -> CanvasGraph {
        let alreadyExists = graph.edgesByID.values.contains { edge in
            edge.relationType == .parentChild
                && edge.fromNodeID == parentNodeID
                && edge.toNodeID == childNodeID
        }
        guard !alreadyExists else {
            return graph
        }
        let normalizedGraph = normalizeParentChildOrder(for: parentNodeID, in: graph)
        let nextOrder = nextParentChildOrder(for: parentNodeID, in: normalizedGraph)
        return try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentNodeID, to: childNodeID, order: nextOrder),
            in: normalizedGraph
        ).get()
    }

    /// Resolves insertion order so duplicate roots are placed next to the source root node.
    private func duplicateRootInsertionOrder(
        parentID: CanvasNodeID,
        sourceRootNodeID: CanvasNodeID,
        graph: CanvasGraph
    ) -> Int {
        let siblingEdges = parentChildEdges(of: parentID, in: graph)
        guard let sourceIndex = siblingEdges.firstIndex(where: { $0.toNodeID == sourceRootNodeID }) else {
            return nextParentChildOrder(for: parentID, in: graph)
        }
        return sourceIndex + 1
    }
}
