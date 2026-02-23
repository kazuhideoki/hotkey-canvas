import Domain

// Background: Tree mode move-node operations include indent and outdent transitions across hierarchy levels.
// Responsibility: Handle tree nesting updates for moveNode left/right directions.
extension ApplyCanvasCommandsUseCase {
    func outdentNode(in graph: CanvasGraph) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return graph
        }
        guard let parentEdge = parentChildIncomingEdge(of: focusedNodeID, in: graph) else {
            return graph
        }
        guard let parentNode = graph.nodesByID[parentEdge.fromNodeID] else {
            return graph
        }
        guard let grandparentNodeID = parentNodeID(of: parentEdge.fromNodeID, in: graph) else {
            return graph
        }
        guard let grandparentNode = graph.nodesByID[grandparentNodeID] else {
            return graph
        }

        guard
            var nextGraph = try outdentedGraph(
                focusedNodeID: focusedNodeID,
                parentNode: parentNode,
                grandparentNode: grandparentNode,
                graph: graph
            )?.0
        else {
            return graph
        }

        let updatedFocusedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            attachments: focusedNode.attachments,
            bounds: CanvasBounds(
                x: parentNode.bounds.x,
                y: parentNode.bounds.y + Self.orderingEpsilon,
                width: focusedNode.bounds.width,
                height: focusedNode.bounds.height
            ),
            metadata: focusedNode.metadata,
            markdownStyleEnabled: focusedNode.markdownStyleEnabled
        )
        nextGraph = CanvasGraph(
            nodesByID: nextGraph.nodesByID.merging(
                [focusedNodeID: updatedFocusedNode], uniquingKeysWith: { _, new in new }),
            edgesByID: nextGraph.edgesByID,
            focusedNodeID: focusedNodeID,
            selectedNodeIDs: nextGraph.selectedNodeIDs,
            collapsedRootNodeIDs: nextGraph.collapsedRootNodeIDs,
            areasByID: nextGraph.areasByID
        )

        return nextGraph
    }

    func outdentedGraph(
        focusedNodeID: CanvasNodeID,
        parentNode: CanvasNode,
        grandparentNode: CanvasNode,
        graph: CanvasGraph
    ) throws -> (CanvasGraph, Int)? {
        var nextGraph = normalizeParentChildOrder(for: grandparentNode.id, in: graph)
        guard
            let parentAsChildEdge = parentChildEdges(of: grandparentNode.id, in: nextGraph).first(where: {
                $0.toNodeID == parentNode.id
            }),
            let parentOrder = parentAsChildEdge.parentChildOrder
        else {
            return nil
        }
        let insertionOrder = parentOrder + 1
        nextGraph = shiftParentChildOrder(
            for: grandparentNode.id,
            atOrAfter: insertionOrder,
            by: 1,
            in: nextGraph
        )

        guard let latestParentEdge = parentChildIncomingEdge(of: focusedNodeID, in: nextGraph) else {
            return nil
        }
        nextGraph = try CanvasGraphCRUDService.deleteEdge(id: latestParentEdge.id, in: nextGraph).get()
        nextGraph = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(
                from: grandparentNode.id,
                to: focusedNodeID,
                order: insertionOrder
            ),
            in: nextGraph
        ).get()
        return (nextGraph, insertionOrder)
    }

    func indentNode(in graph: CanvasGraph) throws -> CanvasGraph {
        guard let focusedNodeID = graph.focusedNodeID else {
            return graph
        }
        guard let focusedNode = graph.nodesByID[focusedNodeID] else {
            return graph
        }
        guard !isTopLevelParent(focusedNodeID, in: graph) else {
            return graph
        }

        let peers = orderedPeerNodes(of: focusedNodeID, in: graph)
        guard let focusedIndex = peers.firstIndex(where: { $0.id == focusedNodeID }) else {
            return graph
        }
        let previousIndex = focusedIndex - 1
        guard peers.indices.contains(previousIndex) else {
            return graph
        }
        let newParent = peers[previousIndex]
        let newParentChildren = childNodes(of: newParent.id, in: graph)
        let appendedChildY = appendedChildY(
            under: newParent,
            existingChildren: newParentChildren
        )

        var nextGraph = graph
        if let currentParentEdge = parentChildIncomingEdge(of: focusedNodeID, in: graph) {
            nextGraph = try CanvasGraphCRUDService.deleteEdge(id: currentParentEdge.id, in: nextGraph).get()
        }
        nextGraph = normalizeParentChildOrder(for: newParent.id, in: nextGraph)
        let appendedOrder = nextParentChildOrder(for: newParent.id, in: nextGraph)
        nextGraph = try CanvasGraphCRUDService.createEdge(
            makeParentChildEdge(from: newParent.id, to: focusedNodeID, order: appendedOrder),
            in: nextGraph
        ).get()

        let updatedFocusedNode = CanvasNode(
            id: focusedNode.id,
            kind: focusedNode.kind,
            text: focusedNode.text,
            attachments: focusedNode.attachments,
            bounds: CanvasBounds(
                x: newParent.bounds.x + newParent.bounds.width + Self.indentHorizontalGap,
                y: appendedChildY,
                width: focusedNode.bounds.width,
                height: focusedNode.bounds.height
            ),
            metadata: focusedNode.metadata,
            markdownStyleEnabled: focusedNode.markdownStyleEnabled
        )
        nextGraph = CanvasGraph(
            nodesByID: nextGraph.nodesByID.merging(
                [focusedNodeID: updatedFocusedNode], uniquingKeysWith: { _, new in new }),
            edgesByID: nextGraph.edgesByID,
            focusedNodeID: nextGraph.collapsedRootNodeIDs.contains(newParent.id) ? newParent.id : focusedNodeID,
            selectedNodeIDs: nextGraph.selectedNodeIDs,
            collapsedRootNodeIDs: nextGraph.collapsedRootNodeIDs,
            areasByID: nextGraph.areasByID
        )

        return nextGraph
    }
}
