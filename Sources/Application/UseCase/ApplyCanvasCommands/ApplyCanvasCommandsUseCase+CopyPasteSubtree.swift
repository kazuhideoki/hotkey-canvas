import Domain
import Foundation

// Background: Tree editing supports in-app copy/cut/paste by reconstructing subtree topology with fresh identifiers.
// Responsibility: Capture focused subtree payload and paste it as a child subtree under the focused node.
extension ApplyCanvasCommandsUseCase {
    /// Copies the focused subtree into in-memory clipboard without mutating graph.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: No-op mutation result while storing clipboard payload.
    func copyFocusedSubtree(in graph: CanvasGraph) -> CanvasMutationResult {
        guard let focusedNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard graph.nodesByID[focusedNodeID] != nil else {
            return noOpMutationResult(for: graph)
        }
        var visitedNodeIDs: Set<CanvasNodeID> = []

        let payload = CanvasTreeClipboardPayload(
            rootNode: makeClipboardNodePayload(
                for: focusedNodeID,
                in: graph,
                visitedNodeIDs: &visitedNodeIDs
            )
        )
        treeClipboardState = .subtree(payload)
        return noOpMutationResult(for: graph)
    }

    /// Cuts focused subtree by first copying payload, then deleting subtree from graph.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Deletion mutation result after clipboard capture.
    /// - Throws: Propagates deletion failures.
    func cutFocusedSubtree(in graph: CanvasGraph) throws -> CanvasMutationResult {
        _ = copyFocusedSubtree(in: graph)
        return try deleteFocusedNode(in: graph)
    }

    /// Pastes clipboard subtree as a child of the focused node with fresh node and edge identifiers.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Mutation result focused on the pasted subtree root.
    /// - Throws: Propagates graph and area mutation failures.
    func pasteSubtreeAsChild(in graph: CanvasGraph) throws -> CanvasMutationResult {
        guard case .subtree(let payload) = treeClipboardState else {
            return noOpMutationResult(for: graph)
        }
        guard let parentNodeID = graph.focusedNodeID else {
            return noOpMutationResult(for: graph)
        }
        guard let parentNode = graph.nodesByID[parentNodeID] else {
            return noOpMutationResult(for: graph)
        }

        let parentAreaID = try CanvasAreaMembershipService.areaID(containing: parentNodeID, in: graph).get()
        var graphAfterMutation = graph
        let insertResult = try insertClipboardSubtree(
            payload.rootNode,
            under: parentNode,
            in: graphAfterMutation
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
            focusedNodeID: insertResult.rootNodeID,
            collapsedRootNodeIDs: nextCollapsedRootNodeIDs,
            areasByID: graphAfterMutation.areasByID
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
            areaLayoutSeedNodeID: insertResult.rootNodeID
        )
    }
}

extension ApplyCanvasCommandsUseCase {
    private struct ClipboardInsertionResult {
        let graph: CanvasGraph
        let rootNodeID: CanvasNodeID
        let insertedNodeIDs: Set<CanvasNodeID>
    }

    /// Serializes subtree rooted at node into ID-independent payload.
    private func makeClipboardNodePayload(
        for nodeID: CanvasNodeID,
        in graph: CanvasGraph
    ) -> CanvasTreeClipboardNodePayload {
        var visitedNodeIDs: Set<CanvasNodeID> = []
        return makeClipboardNodePayload(
            for: nodeID,
            in: graph,
            visitedNodeIDs: &visitedNodeIDs
        )
    }

    /// Serializes subtree rooted at node into ID-independent payload while preventing cycle recursion.
    private func makeClipboardNodePayload(
        for nodeID: CanvasNodeID,
        in graph: CanvasGraph,
        visitedNodeIDs: inout Set<CanvasNodeID>
    ) -> CanvasTreeClipboardNodePayload {
        guard let node = graph.nodesByID[nodeID] else {
            preconditionFailure("Focused subtree payload requested for missing node: \(nodeID.rawValue)")
        }
        visitedNodeIDs.insert(nodeID)

        let childrenPayload = childNodes(of: nodeID, in: graph)
            .filter { !visitedNodeIDs.contains($0.id) }
            .map { childNode in
                makeClipboardNodePayload(
                    for: childNode.id,
                    in: graph,
                    visitedNodeIDs: &visitedNodeIDs
                )
            }
        return CanvasTreeClipboardNodePayload(
            kind: node.kind,
            text: node.text,
            markdownStyleEnabled: node.markdownStyleEnabled,
            metadata: node.metadata,
            children: childrenPayload
        )
    }

    /// Inserts clipboard payload recursively under the provided parent node.
    private func insertClipboardSubtree(
        _ payload: CanvasTreeClipboardNodePayload,
        under parentNode: CanvasNode,
        in graph: CanvasGraph
    ) throws -> ClipboardInsertionResult {
        let siblingAreaNodeIDs = parentChildAreaNodeIDs(containing: parentNode.id, in: graph)
        let rootBounds = calculateChildBounds(
            for: parentNode,
            in: graph,
            avoiding: siblingAreaNodeIDs
        )
        let rootNode = CanvasNode(
            id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
            kind: payload.kind,
            text: payload.text,
            bounds: rootBounds,
            metadata: payload.metadata,
            markdownStyleEnabled: payload.markdownStyleEnabled
        )

        var nextGraph = try CanvasGraphCRUDService.createNode(rootNode, in: graph).get()
        nextGraph = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: parentNode.id, to: rootNode.id),
            in: nextGraph
        ).get()
        var insertedNodeIDs: Set<CanvasNodeID> = [rootNode.id]

        for childPayload in payload.children {
            let childResult = try insertClipboardSubtree(childPayload, under: rootNode, in: nextGraph)
            nextGraph = childResult.graph
            insertedNodeIDs.formUnion(childResult.insertedNodeIDs)
        }

        return ClipboardInsertionResult(
            graph: nextGraph,
            rootNodeID: rootNode.id,
            insertedNodeIDs: insertedNodeIDs
        )
    }
}
