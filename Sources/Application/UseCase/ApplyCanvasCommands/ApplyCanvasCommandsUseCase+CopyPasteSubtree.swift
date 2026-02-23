import Domain
import Foundation

// Background: Tree and diagram editing support in-app copy/cut/paste
// by reconstructing copied node sets with fresh identifiers.
// Responsibility: Capture selected/focused nodes into clipboard payload and paste them in the focused area.
extension ApplyCanvasCommandsUseCase {
    /// Copies multiple selected nodes when available, otherwise copies the focused subtree.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: No-op mutation result while storing clipboard payload.
    func copyFocusedSubtree(in graph: CanvasGraph) -> CanvasMutationResult {
        let selectedNodeIDs = multiSelectedNodeIDsInFocusedArea(in: graph)
        if selectedNodeIDs.count > 1 {
            treeClipboardState = .subtree(makeClipboardPayload(from: selectedNodeIDs, in: graph))
            return noOpMutationResult(for: graph)
        }

        guard let focusedNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard graph.nodesByID[focusedNodeID] != nil else {
            return noOpMutationResult(for: graph)
        }

        let subtreeNodeIDs = descendantNodeIDs(of: focusedNodeID, in: graph)
            .union([focusedNodeID])
        treeClipboardState = .subtree(makeClipboardPayload(from: subtreeNodeIDs, in: graph))
        return noOpMutationResult(for: graph)
    }

    /// Cuts multiple selected nodes when available, otherwise cuts the focused subtree.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Deletion mutation result after clipboard capture.
    /// - Throws: Propagates deletion failures.
    func cutFocusedSubtree(in graph: CanvasGraph) throws -> CanvasMutationResult {
        let selectedNodeIDs = multiSelectedNodeIDsInFocusedArea(in: graph)
        if selectedNodeIDs.count > 1 {
            treeClipboardState = .subtree(makeClipboardPayload(from: selectedNodeIDs, in: graph))
            return try deleteSelectedNodes(selectedNodeIDs, in: graph)
        }

        _ = copyFocusedSubtree(in: graph)
        let focusedAreaID = try CanvasAreaMembershipService.focusedAreaID(in: graph).get()
        let focusedArea = try CanvasAreaMembershipService.area(withID: focusedAreaID, in: graph).get()
        return try deleteFocusedNode(
            in: graph,
            areaID: focusedAreaID,
            areaMode: focusedArea.editingMode
        )
    }

    /// Pastes clipboard nodes into the focused area using mode-specific placement and parent attachment rules.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Mutation result focused on the pasted root node.
    /// - Throws: Propagates graph and area mutation failures.
    func pasteSubtreeAsChild(in graph: CanvasGraph) throws -> CanvasMutationResult {
        guard case .subtree(let payload) = treeClipboardState else {
            return noOpMutationResult(for: graph)
        }
        guard !payload.nodes.isEmpty else {
            return noOpMutationResult(for: graph)
        }
        guard let parentNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard let parentNode = graph.nodesByID[parentNodeID] else {
            return noOpMutationResult(for: graph)
        }

        let parentAreaID = try CanvasAreaMembershipService.areaID(containing: parentNodeID, in: graph).get()
        let parentArea = try CanvasAreaMembershipService.area(withID: parentAreaID, in: graph).get()
        let insertionOrigin = pasteInsertionOrigin(
            for: payload,
            in: graph,
            parentNode: parentNode,
            parentArea: parentArea
        )
        var graphAfterMutation = graph
        let insertResult = try insertClipboardPayload(
            payload,
            at: insertionOrigin,
            under: parentNode,
            in: graphAfterMutation,
            mode: parentArea.editingMode
        )
        graphAfterMutation = insertResult.graph
        graphAfterMutation = try CanvasAreaMembershipService.assign(
            nodeIDs: insertResult.insertedNodeIDs,
            to: parentAreaID,
            in: graphAfterMutation
        ).get()

        var nextCollapsedRootNodeIDs = graphAfterMutation.collapsedRootNodeIDs
        nextCollapsedRootNodeIDs.remove(parentNodeID)
        let nextGraph = CanvasGraph(
            nodesByID: graphAfterMutation.nodesByID,
            edgesByID: graphAfterMutation.edgesByID,
            focusedNodeID: insertResult.primaryRootNodeID,
            selectedNodeIDs: [insertResult.primaryRootNodeID],
            collapsedRootNodeIDs: nextCollapsedRootNodeIDs,
            areasByID: graphAfterMutation.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: parentArea.editingMode == .tree,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: insertResult.primaryRootNodeID
        )
    }
}

extension ApplyCanvasCommandsUseCase {
    private struct ClipboardInsertionResult {
        let graph: CanvasGraph
        let primaryRootNodeID: CanvasNodeID
        let insertedNodeIDs: Set<CanvasNodeID>
    }

    /// Returns selected nodes in the focused area when more than one node is selected.
    private func multiSelectedNodeIDsInFocusedArea(in graph: CanvasGraph) -> Set<CanvasNodeID> {
        guard let focusedNodeID = graph.focusedNodeID else {
            return []
        }
        let focusedAreaID = areaID(containing: focusedNodeID, in: graph)
        guard let focusedAreaID else {
            return []
        }

        let selectedNodeIDs = graph.selectedNodeIDs
            .filter { selectedNodeID in
                graph.nodesByID[selectedNodeID] != nil
                    && areaID(containing: selectedNodeID, in: graph) == focusedAreaID
            }
        guard selectedNodeIDs.count > 1 else {
            return []
        }
        return Set(selectedNodeIDs)
    }

    /// Converts copied node identifiers into a deterministic clipboard payload.
    private func makeClipboardPayload(
        from nodeIDs: Set<CanvasNodeID>,
        in graph: CanvasGraph
    ) -> CanvasClipboardPayload {
        let graphForCopy = graphByNormalizingParentChildOrderForCopiedSubtree(
            nodeIDs: nodeIDs,
            in: graph
        )
        let sortedNodeIDs = nodeIDs.sorted { $0.rawValue < $1.rawValue }
        let nodePayloads = sortedNodeIDs.compactMap { nodeID in
            makeClipboardNodePayload(for: nodeID, in: graphForCopy)
        }

        let internalEdges = graphForCopy.edgesByID.values
            .filter { edge in
                nodeIDs.contains(edge.fromNodeID) && nodeIDs.contains(edge.toNodeID)
            }
            .sorted { $0.id.rawValue < $1.id.rawValue }
            .map { edge in
                CanvasClipboardEdgePayload(
                    fromSourceReferenceID: edge.fromNodeID.rawValue,
                    toSourceReferenceID: edge.toNodeID.rawValue,
                    relationType: edge.relationType,
                    parentChildOrder: edge.parentChildOrder
                )
            }

        let rootNodeReferenceIDs = treeRootReferenceIDs(in: nodeIDs, edgesByID: graphForCopy.edgesByID)
        return CanvasClipboardPayload(
            nodes: nodePayloads,
            edges: internalEdges,
            rootNodeReferenceIDs: rootNodeReferenceIDs
        )
    }

    /// Creates one clipboard node payload from the graph snapshot.
    private func makeClipboardNodePayload(
        for nodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> CanvasClipboardNodePayload? {
        guard let node = graph.nodesByID[nodeID] else {
            return nil
        }
        return CanvasClipboardNodePayload(
            sourceReferenceID: nodeID.rawValue,
            kind: node.kind,
            text: node.text,
            attachments: node.attachments,
            markdownStyleEnabled: node.markdownStyleEnabled,
            metadata: node.metadata,
            bounds: node.bounds
        )
    }

    /// Resolves tree roots from copied nodes and parent-child internal edges.
    private func treeRootReferenceIDs(
        in nodeIDs: Set<CanvasNodeID>,
        edgesByID: [CanvasEdgeID: CanvasEdge]
    ) -> [String] {
        let incomingNodeIDs = Set(
            edgesByID.values
                .filter { edge in
                    edge.relationType == .parentChild
                        && nodeIDs.contains(edge.fromNodeID)
                        && nodeIDs.contains(edge.toNodeID)
                }
                .map(\.toNodeID)
        )

        let rootReferenceIDs =
            nodeIDs
            .filter { !incomingNodeIDs.contains($0) }
            .map(\.rawValue)
            .sorted()

        if !rootReferenceIDs.isEmpty {
            return rootReferenceIDs
        }

        return nodeIDs.map(\.rawValue).sorted().prefix(1).map { $0 }
    }

    /// Computes insertion origin for pasted content in the focused area.
    private func pasteInsertionOrigin(
        for payload: CanvasClipboardPayload,
        in graph: CanvasGraph,
        parentNode: CanvasNode,
        parentArea: CanvasArea
    ) -> (x: Double, y: Double) {
        let sourceMinBounds = payload.nodes.reduce(
            (x: Double.greatestFiniteMagnitude, y: Double.greatestFiniteMagnitude)
        ) { current, node in
            (x: min(current.x, node.bounds.x), y: min(current.y, node.bounds.y))
        }

        switch parentArea.editingMode {
        case .tree:
            let siblingAreaNodeIDs = parentChildAreaNodeIDs(containing: parentNode.id, in: graph)
            let rootBounds = calculateChildBounds(
                for: parentNode,
                in: graph,
                avoiding: siblingAreaNodeIDs
            )
            return (x: rootBounds.x, y: rootBounds.y)
        case .diagram:
            let sourceMaxX = payload.nodes.map { $0.bounds.x + $0.bounds.width }.max() ?? sourceMinBounds.x
            let sourceMaxY = payload.nodes.map { $0.bounds.y + $0.bounds.height }.max() ?? sourceMinBounds.y
            let groupWidth = max(0, sourceMaxX - sourceMinBounds.x)
            let groupHeight = max(0, sourceMaxY - sourceMinBounds.y)
            let occupiedNodeIDs = parentArea.nodeIDs
            let candidateBounds = makeAvailableNewNodeBounds(
                in: graph,
                avoiding: occupiedNodeIDs,
                width: groupWidth,
                height: groupHeight,
                verticalSpacing: CanvasDefaultNodeDistance.vertical(for: .diagram)
            )
            return (x: candidateBounds.x, y: candidateBounds.y)
        }
    }

    /// Inserts copied nodes/edges with fresh identifiers and optional parent attachment for tree mode.
    private func insertClipboardPayload(
        _ payload: CanvasClipboardPayload,
        at origin: (x: Double, y: Double),
        under parentNode: CanvasNode,
        in graph: CanvasGraph,
        mode: CanvasEditingMode
    ) throws -> ClipboardInsertionResult {
        let sourceMinX = payload.nodes.map(\.bounds.x).min() ?? 0
        let sourceMinY = payload.nodes.map(\.bounds.y).min() ?? 0

        var nextGraph = graph
        var mappedNodeIDBySourceReferenceID: [String: CanvasNodeID] = [:]
        let insertedNodeIDs = try insertClipboardNodes(
            payload.nodes,
            at: origin,
            sourceMin: (x: sourceMinX, y: sourceMinY),
            into: &nextGraph,
            mappedNodeIDBySourceReferenceID: &mappedNodeIDBySourceReferenceID
        )
        try insertClipboardEdges(
            payload.edges,
            mappedNodeIDBySourceReferenceID: mappedNodeIDBySourceReferenceID,
            into: &nextGraph
        )

        let sortedRootReferences = payload.rootNodeReferenceIDs.sorted()
        let mappedRootNodeIDs = sortedRootReferences.compactMap { mappedNodeIDBySourceReferenceID[$0] }
        let mappedNodeIDsInPayloadOrder = payload.nodes
            .sorted(by: { $0.sourceReferenceID < $1.sourceReferenceID })
            .compactMap { mappedNodeIDBySourceReferenceID[$0.sourceReferenceID] }
        try attachTreeRootEdgesIfNeeded(
            mode: mode,
            rootNodeIDs: mappedRootNodeIDs,
            parentNodeID: parentNode.id,
            graph: &nextGraph
        )

        let primaryRootNodeID =
            mappedRootNodeIDs.first
            ?? mappedNodeIDsInPayloadOrder.first
            ?? parentNode.id

        return ClipboardInsertionResult(
            graph: nextGraph,
            primaryRootNodeID: primaryRootNodeID,
            insertedNodeIDs: insertedNodeIDs
        )
    }

    /// Inserts copied nodes and returns created node identifiers.
    private func insertClipboardNodes(
        _ nodePayloads: [CanvasClipboardNodePayload],
        at origin: (x: Double, y: Double),
        sourceMin: (x: Double, y: Double),
        into graph: inout CanvasGraph,
        mappedNodeIDBySourceReferenceID: inout [String: CanvasNodeID]
    ) throws -> Set<CanvasNodeID> {
        let sortedNodePayloads = nodePayloads.sorted { $0.sourceReferenceID < $1.sourceReferenceID }
        var insertedNodeIDs: Set<CanvasNodeID> = []
        for nodePayload in sortedNodePayloads {
            let nextNodeID = CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())")
            let translatedBounds = CanvasBounds(
                x: origin.x + (nodePayload.bounds.x - sourceMin.x),
                y: origin.y + (nodePayload.bounds.y - sourceMin.y),
                width: nodePayload.bounds.width,
                height: nodePayload.bounds.height
            )
            let newNode = CanvasNode(
                id: nextNodeID,
                kind: nodePayload.kind,
                text: nodePayload.text,
                attachments: nodePayload.attachments,
                bounds: translatedBounds,
                metadata: nodePayload.metadata,
                markdownStyleEnabled: nodePayload.markdownStyleEnabled
            )
            graph = try CanvasGraphCRUDService.createNode(newNode, in: graph).get()
            mappedNodeIDBySourceReferenceID[nodePayload.sourceReferenceID] = nextNodeID
            insertedNodeIDs.insert(nextNodeID)
        }
        return insertedNodeIDs
    }

    /// Inserts copied internal edges between already inserted nodes.
    private func insertClipboardEdges(
        _ edgePayloads: [CanvasClipboardEdgePayload],
        mappedNodeIDBySourceReferenceID: [String: CanvasNodeID],
        into graph: inout CanvasGraph
    ) throws {
        let sortedEdgePayloads = edgePayloads.sorted {
            if $0.fromSourceReferenceID != $1.fromSourceReferenceID {
                return $0.fromSourceReferenceID < $1.fromSourceReferenceID
            }
            if $0.toSourceReferenceID != $1.toSourceReferenceID {
                return $0.toSourceReferenceID < $1.toSourceReferenceID
            }
            if $0.parentChildOrder != $1.parentChildOrder {
                return ($0.parentChildOrder ?? Int.max) < ($1.parentChildOrder ?? Int.max)
            }
            return $0.relationType.rawValue < $1.relationType.rawValue
        }
        for edgePayload in sortedEdgePayloads {
            guard let fromNodeID = mappedNodeIDBySourceReferenceID[edgePayload.fromSourceReferenceID] else {
                continue
            }
            guard let toNodeID = mappedNodeIDBySourceReferenceID[edgePayload.toSourceReferenceID] else {
                continue
            }
            let newEdge = CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-\(UUID().uuidString.lowercased())"),
                fromNodeID: fromNodeID,
                toNodeID: toNodeID,
                relationType: edgePayload.relationType,
                parentChildOrder: edgePayload.parentChildOrder
            )
            graph = try CanvasGraphCRUDService.createEdge(newEdge, in: graph).get()
        }
    }

    /// Attaches pasted roots under parent when tree mode requires parent-child connection.
    private func attachTreeRootEdgesIfNeeded(
        mode: CanvasEditingMode,
        rootNodeIDs: [CanvasNodeID],
        parentNodeID: CanvasNodeID,
        graph: inout CanvasGraph
    ) throws {
        guard mode == .tree else {
            return
        }
        graph = normalizeParentChildOrder(for: parentNodeID, in: graph)
        var nextOrder = nextParentChildOrder(for: parentNodeID, in: graph)
        for rootNodeID in rootNodeIDs {
            graph = try CanvasGraphCRUDService.createEdge(
                makeParentChildEdge(from: parentNodeID, to: rootNodeID, order: nextOrder),
                in: graph
            ).get()
            nextOrder += 1
        }
    }

    /// Deletes the selected node set and picks deterministic next focus.
    private func deleteSelectedNodes(
        _ nodeIDsToDelete: Set<CanvasNodeID>,
        in graph: CanvasGraph
    ) throws -> CanvasMutationResult {
        guard !nodeIDsToDelete.isEmpty else {
            return noOpMutationResult(for: graph)
        }

        let focusedNodeBeforeDelete = graph.focusedNodeID.flatMap { graph.nodesByID[$0] }
        var graphAfterDelete = graph
        for nodeID in nodeIDsToDelete.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard graphAfterDelete.nodesByID[nodeID] != nil else {
                continue
            }
            graphAfterDelete = try CanvasGraphCRUDService.deleteNode(id: nodeID, in: graphAfterDelete).get()
        }
        graphAfterDelete = CanvasAreaMembershipService.remove(nodeIDs: nodeIDsToDelete, in: graphAfterDelete)

        let graphAfterTreeLayoutPreview = relayoutParentChildTrees(in: graphAfterDelete)
        let nextFocusedNodeID: CanvasNodeID?
        if let focusedNodeID = graph.focusedNodeID,
            !nodeIDsToDelete.contains(focusedNodeID),
            graphAfterDelete.nodesByID[focusedNodeID] != nil
        {
            nextFocusedNodeID = focusedNodeID
        } else if let focusedNodeBeforeDelete {
            nextFocusedNodeID = nearestRemainingNodeID(
                to: focusedNodeBeforeDelete,
                in: graphAfterTreeLayoutPreview
            )
        } else {
            nextFocusedNodeID = nil
        }

        let nextGraph = CanvasGraph(
            nodesByID: graphAfterDelete.nodesByID,
            edgesByID: graphAfterDelete.edgesByID,
            focusedNodeID: nextFocusedNodeID,
            selectedNodeIDs: nextFocusedNodeID.map { [$0] } ?? [],
            collapsedRootNodeIDs: CanvasFoldedSubtreeVisibilityService.normalizedCollapsedRootNodeIDs(
                in: graphAfterDelete
            ),
            areasByID: graphAfterDelete.areasByID
        )
        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: nextFocusedNodeID != nil,
                needsFocusNormalization: true
            ),
            areaLayoutSeedNodeID: nextFocusedNodeID
        )
    }

    /// Returns area identifier for the given node when membership data is valid.
    private func areaID(containing nodeID: CanvasNodeID, in graph: CanvasGraph) -> CanvasAreaID? {
        switch CanvasAreaMembershipService.areaID(containing: nodeID, in: graph) {
        case .success(let areaID):
            return areaID
        case .failure:
            return nil
        }
    }

    /// Finds nearest remaining node center to preserve editing continuity after multi-node deletion.
    private func nearestRemainingNodeID(to sourceNode: CanvasNode, in graph: CanvasGraph) -> CanvasNodeID? {
        let sourceCenter = nodeCenter(for: sourceNode)
        return graph.nodesByID.values.min { lhs, rhs in
            let lhsDistance = squaredDistance(from: sourceCenter, to: nodeCenter(for: lhs))
            let rhsDistance = squaredDistance(from: sourceCenter, to: nodeCenter(for: rhs))
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            if lhs.bounds.y != rhs.bounds.y {
                return lhs.bounds.y < rhs.bounds.y
            }
            if lhs.bounds.x != rhs.bounds.x {
                return lhs.bounds.x < rhs.bounds.x
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }?.id
    }
}
