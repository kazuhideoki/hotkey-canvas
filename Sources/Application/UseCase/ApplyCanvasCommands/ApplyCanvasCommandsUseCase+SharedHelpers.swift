import Domain
import Foundation

// Background: Multiple canvas command handlers reuse placement and edge-construction helpers.
// Responsibility: Provide shared node/edge creation and placement routines.
extension ApplyCanvasCommandsUseCase {
    /// Returns selected node identifiers constrained to the focused node's area.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Deterministically sorted selected node identifiers in the focused area.
    func selectedNodeIDsInFocusedArea(in graph: CanvasGraph) -> [CanvasNodeID] {
        guard let focusedNodeID = graph.focusedNodeID else {
            return []
        }
        guard graph.nodesByID[focusedNodeID] != nil else {
            return []
        }
        let focusedAreaID: CanvasAreaID
        switch CanvasAreaMembershipService.areaID(containing: focusedNodeID, in: graph) {
        case .success(let areaID):
            focusedAreaID = areaID
        case .failure:
            return []
        }
        return graph.selectedNodeIDs
            .filter { selectedNodeID in
                guard graph.nodesByID[selectedNodeID] != nil else {
                    return false
                }
                switch CanvasAreaMembershipService.areaID(containing: selectedNodeID, in: graph) {
                case .success(let selectedAreaID):
                    return selectedAreaID == focusedAreaID
                case .failure:
                    return false
                }
            }
            .sorted(by: { $0.rawValue < $1.rawValue })
    }

    static let newNodeWidth: Double = CanvasDefaultNodeDistance.treeNodeWidth
    static let newNodeHeight: Double = CanvasDefaultNodeDistance.treeNodeHeight
    static let defaultNewNodeX: Double = 48
    static let defaultNewNodeY: Double = 48
    static let newNodeVerticalSpacing: Double = CanvasDefaultNodeDistance.treeVertical
    static let childHorizontalGap: Double = CanvasDefaultNodeDistance.treeHorizontal
    static let areaCollisionSpacing: Double = CanvasDefaultNodeDistance.treeHorizontal
    static let nodeCreatedOrderMetadataKey = "createdOrder"

    /// Creates a default text node using the provided bounds.
    /// - Parameter bounds: Bounds to assign to the new node.
    /// - Returns: A text node with a generated identifier.
    func makeTextNode(bounds: CanvasBounds, in graph: CanvasGraph) -> CanvasNode {
        CanvasNode(
            id: CanvasNodeID(rawValue: "node-\(UUID().uuidString.lowercased())"),
            kind: .text,
            text: nil,
            attachments: [],
            bounds: bounds,
            metadata: [Self.nodeCreatedOrderMetadataKey: String(nextNodeCreatedOrder(in: graph))]
        )
    }

    /// Returns the next monotonic created-order value for new nodes.
    /// - Parameter graph: Current graph snapshot.
    /// - Returns: Next created-order value.
    func nextNodeCreatedOrder(in graph: CanvasGraph) -> Int {
        var maxCreatedOrder: Int?
        for node in graph.nodesByID.values {
            guard
                let rawValue = node.metadata[Self.nodeCreatedOrderMetadataKey],
                let createdOrder = Int(rawValue)
            else {
                continue
            }
            if let currentMax = maxCreatedOrder {
                maxCreatedOrder = max(currentMax, createdOrder)
            } else {
                maxCreatedOrder = createdOrder
            }
        }
        return (maxCreatedOrder ?? -1) + 1
    }

    /// Creates a parent-child edge between two nodes.
    /// - Parameters:
    ///   - parentID: Source node identifier treated as the parent.
    ///   - childID: Destination node identifier treated as the child.
    ///   - order: Stable sibling order under the parent.
    /// - Returns: A parent-child edge with a generated identifier.
    func makeParentChildEdge(
        from parentID: CanvasNodeID,
        to childID: CanvasNodeID,
        order: Int
    ) -> CanvasEdge {
        CanvasEdge(
            id: CanvasEdgeID(rawValue: "edge-\(UUID().uuidString.lowercased())"),
            fromNodeID: parentID,
            toNodeID: childID,
            relationType: .parentChild,
            parentChildOrder: order
        )
    }

    /// Computes bounds for a newly inserted node using default collision targets.
    /// - Parameter graph: Current canvas graph.
    /// - Returns: First available node bounds from the insertion anchor.
    func makeAvailableNewNodeBounds(in graph: CanvasGraph) -> CanvasBounds {
        makeAvailableNewNodeBounds(
            in: graph,
            width: Self.newNodeWidth,
            height: Self.newNodeHeight
        )
    }

    /// Computes bounds for a newly inserted node using custom size and default collision targets.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - width: New node width.
    ///   - height: New node height.
    /// - Returns: First available node bounds from the insertion anchor.
    func makeAvailableNewNodeBounds(
        in graph: CanvasGraph,
        width: Double,
        height: Double
    ) -> CanvasBounds {
        let anchor = addNodePlacementAnchor(in: graph)
        let startX = anchor?.parentNode.bounds.x ?? Self.defaultNewNodeX
        let startY: Double
        if let parentNode = anchor?.parentNode {
            startY = parentNode.bounds.y + parentNode.bounds.height + Self.newNodeVerticalSpacing
        } else {
            startY = Self.defaultNewNodeY
        }
        var candidate = CanvasBounds(
            x: startX,
            y: startY,
            width: width,
            height: height
        )
        let areas = CanvasAreaLayoutService.makeParentChildAreas(in: graph)
        while let overlappedArea = firstOverlappedArea(for: candidate, in: areas) {
            candidate = CanvasBounds(
                x: candidate.x,
                y: overlappedArea.bounds.maxY + Self.areaCollisionSpacing,
                width: candidate.width,
                height: candidate.height
            )
        }
        return candidate
    }

    /// Computes bounds for a newly inserted node while avoiding overlap against the given node set.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - nodeIDs: Nodes to consider as placement blockers.
    /// - Returns: First available non-overlapping bounds.
    func makeAvailableNewNodeBounds(
        in graph: CanvasGraph,
        avoiding nodeIDs: Set<CanvasNodeID>
    ) -> CanvasBounds {
        makeAvailableNewNodeBounds(
            in: graph,
            avoiding: nodeIDs,
            width: Self.newNodeWidth,
            height: Self.newNodeHeight
        )
    }

    /// Computes bounds for a newly inserted node while avoiding overlap against the given node set.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - nodeIDs: Nodes to consider as placement blockers.
    ///   - width: New node width.
    ///   - height: New node height.
    /// - Returns: First available non-overlapping bounds.
    func makeAvailableNewNodeBounds(
        in graph: CanvasGraph,
        avoiding nodeIDs: Set<CanvasNodeID>,
        width: Double,
        height: Double,
        verticalSpacing: Double = ApplyCanvasCommandsUseCase.newNodeVerticalSpacing
    ) -> CanvasBounds {
        let focusedNode = graph.focusedNodeID.flatMap { graph.nodesByID[$0] }
        let startX = focusedNode?.bounds.x ?? Self.defaultNewNodeX
        let startY =
            if let focusedNode {
                focusedNode.bounds.y + focusedNode.bounds.height + verticalSpacing
            } else {
                Self.defaultNewNodeY
            }

        var candidate = CanvasBounds(
            x: startX,
            y: startY,
            width: width,
            height: height
        )
        let collisionNodes = nodesForPlacementCollision(in: graph, avoiding: nodeIDs)
        while let overlappedNode = firstOverlappedNode(for: candidate, in: collisionNodes) {
            candidate = CanvasBounds(
                x: candidate.x,
                y: overlappedNode.bounds.y + overlappedNode.bounds.height + verticalSpacing,
                width: candidate.width,
                height: candidate.height
            )
        }
        return candidate
    }

    /// Computes diagram-node bounds by following the focused node's incoming direction when available.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - nodeIDs: Nodes to consider as placement blockers.
    ///   - width: New node width.
    ///   - height: New node height.
    ///   - verticalSpacing: Fallback spacing used when directional context is unavailable.
    /// - Returns: First available non-overlapping bounds in the inferred direction.
    func makeAvailableDiagramNewNodeBounds(
        in graph: CanvasGraph,
        avoiding nodeIDs: Set<CanvasNodeID>,
        width: Double,
        height: Double,
        verticalSpacing: Double = ApplyCanvasCommandsUseCase.newNodeVerticalSpacing
    ) -> CanvasBounds {
        guard
            let focusedNodeID = graph.focusedNodeID,
            let focusedNode = graph.nodesByID[focusedNodeID],
            let anchorNode = diagramIncomingAnchorNode(of: focusedNodeID, in: graph),
            let unit = diagramDirectionalUnit(from: anchorNode, to: focusedNode)
        else {
            return makeAvailableNewNodeBounds(
                in: graph,
                avoiding: nodeIDs,
                width: width,
                height: height,
                verticalSpacing: verticalSpacing
            )
        }

        let focusedCenterX = focusedNode.bounds.x + (focusedNode.bounds.width / 2)
        let focusedCenterY = focusedNode.bounds.y + (focusedNode.bounds.height / 2)
        let horizontalDistance =
            ((focusedNode.bounds.width + width) / 2) + CanvasDefaultNodeDistance.diagramHorizontal
        let verticalDistance =
            ((focusedNode.bounds.height + height) / 2) + CanvasDefaultNodeDistance.vertical(for: .diagram)
        var candidate = CanvasBounds(
            x: focusedCenterX + (Double(unit.dx) * horizontalDistance) - (width / 2),
            y: focusedCenterY + (Double(unit.dy) * verticalDistance) - (height / 2),
            width: width,
            height: height
        )
        let collisionNodes = nodesForPlacementCollision(in: graph, avoiding: nodeIDs)
        let horizontalStep = width + CanvasDefaultNodeDistance.diagramHorizontal
        let verticalStep = height + CanvasDefaultNodeDistance.vertical(for: .diagram)
        while hasOverlappingNode(candidate, in: collisionNodes) {
            candidate = CanvasBounds(
                x: candidate.x + (Double(unit.dx) * horizontalStep),
                y: candidate.y + (Double(unit.dy) * verticalStep),
                width: candidate.width,
                height: candidate.height
            )
        }
        return candidate
    }

    /// Computes sibling-node bounds for insertion around the focused node.
    /// - Parameters:
    ///   - graph: Current canvas graph.
    ///   - parentID: Parent node identifier shared by siblings.
    ///   - focusedNode: Focused sibling used as insertion anchor.
    ///   - position: Relative insertion side from the focused sibling.
    /// - Returns: Bounds used to create the new sibling node.
    func makeSiblingNodeBounds(
        in graph: CanvasGraph,
        parentID: CanvasNodeID,
        focusedNode: CanvasNode,
        position: CanvasSiblingNodePosition
    ) -> CanvasBounds {
        let siblingNodes = childNodes(of: parentID, in: graph)
        let focusedIndex = siblingNodes.firstIndex(where: { $0.id == focusedNode.id })
        let y = makeSiblingInsertionY(
            focusedNode: focusedNode,
            siblings: siblingNodes,
            focusedIndex: focusedIndex,
            position: position
        )

        return CanvasBounds(
            x: focusedNode.bounds.x,
            y: y,
            width: Self.newNodeWidth,
            height: Self.newNodeHeight
        )
    }

    /// Returns children of a parent sorted by stable sibling order and visual fallback order.
    /// - Parameters:
    ///   - parentID: Parent node identifier.
    ///   - graph: Current canvas graph.
    /// - Returns: Child nodes sorted by sibling order and deterministic visual fallback.
    func childNodes(of parentID: CanvasNodeID, in graph: CanvasGraph) -> [CanvasNode] {
        parentChildEdges(of: parentID, in: graph)
            .compactMap { graph.nodesByID[$0.toNodeID] }
    }

    /// Computes insertion Y that preserves requested above/below order in sibling sorting.
    /// - Parameters:
    ///   - focusedNode: Focused sibling node.
    ///   - siblings: Siblings sorted by visual order.
    ///   - focusedIndex: Index of focused node inside `siblings`.
    ///   - position: Relative insertion side from focused sibling.
    /// - Returns: Candidate Y for the new sibling node.
    private func makeSiblingInsertionY(
        focusedNode: CanvasNode,
        siblings: [CanvasNode],
        focusedIndex: Int?,
        position: CanvasSiblingNodePosition
    ) -> Double {
        let orderingEpsilon = 0.001

        switch position {
        case .above:
            let upperBound = focusedNode.bounds.y - orderingEpsilon
            guard
                let focusedIndex,
                focusedIndex > 0
            else {
                return focusedNode.bounds.y - Self.newNodeHeight - Self.newNodeVerticalSpacing
            }
            let previousSibling = siblings[focusedIndex - 1]
            let lowerBound = previousSibling.bounds.y + orderingEpsilon
            guard lowerBound <= upperBound else {
                return upperBound
            }
            let midpoint = (previousSibling.bounds.y + focusedNode.bounds.y) / 2
            return max(lowerBound, min(upperBound, midpoint))
        case .below:
            let lowerBound = focusedNode.bounds.y + orderingEpsilon
            guard
                let focusedIndex,
                focusedIndex + 1 < siblings.count
            else {
                return focusedNode.bounds.y + focusedNode.bounds.height + Self.newNodeVerticalSpacing
            }
            let nextSibling = siblings[focusedIndex + 1]
            let upperBound = nextSibling.bounds.y - orderingEpsilon
            guard lowerBound <= upperBound else {
                return lowerBound
            }
            let midpoint = (focusedNode.bounds.y + nextSibling.bounds.y) / 2
            return min(upperBound, max(lowerBound, midpoint))
        }
    }

    /// Computes child-node bounds to the right of the parent while avoiding overlap.
    /// - Parameters:
    ///   - parentNode: Parent node used as placement anchor.
    ///   - graph: Current canvas graph.
    ///   - nodeIDs: Nodes to consider as placement blockers.
    /// - Returns: Non-overlapping bounds for the child node.
    func calculateChildBounds(
        for parentNode: CanvasNode,
        in graph: CanvasGraph,
        avoiding nodeIDs: Set<CanvasNodeID>
    ) -> CanvasBounds {
        let width = parentNode.bounds.width
        let height = parentNode.bounds.height
        let y = parentNode.bounds.y

        var x = parentNode.bounds.x + parentNode.bounds.width + Self.childHorizontalGap
        var candidate = CanvasBounds(x: x, y: y, width: width, height: height)
        let collisionNodes = nodesForPlacementCollision(in: graph, avoiding: nodeIDs)

        while hasOverlappingNode(candidate, in: collisionNodes) {
            x += width + Self.childHorizontalGap
            candidate = CanvasBounds(x: x, y: y, width: width, height: height)
        }
        return candidate
    }

    /// Chooses the insertion anchor for top-level node creation from the bottom-most area.
}
