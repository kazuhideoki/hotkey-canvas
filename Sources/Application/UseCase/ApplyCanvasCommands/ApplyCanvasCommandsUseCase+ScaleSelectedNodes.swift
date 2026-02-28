import Domain

// Background: Keyboard-first editing needs a deterministic command to scale selected nodes in both area modes.
// Responsibility: Apply ratio-based node scaling to selected nodes and preserve per-mode size invariants.
extension ApplyCanvasCommandsUseCase {
    /// Scales selected nodes in the current graph.
    /// - Parameters:
    ///   - graph: Current graph snapshot.
    ///   - direction: Scale direction.
    /// - Returns: Mutation result with relayout effects when at least one node changes.
    /// - Throws: Propagates area resolution and node update failures.
    func scaleSelectedNodes(
        in graph: CanvasGraph,
        direction: CanvasNodeScaleDirection
    ) throws -> CanvasMutationResult {
        let selectedNodeIDs = selectedNodeIDsInFocusedArea(in: graph)
        guard !selectedNodeIDs.isEmpty else {
            return noOpMutationResult(for: graph)
        }

        var nextGraph = graph
        var didMutate = false

        for nodeID in selectedNodeIDs {
            guard let node = nextGraph.nodesByID[nodeID] else {
                continue
            }
            let areaID = try CanvasAreaMembershipService.areaID(containing: nodeID, in: nextGraph).get()
            let area = try CanvasAreaMembershipService.area(withID: areaID, in: nextGraph).get()

            let scaledBounds: CanvasBounds
            switch area.editingMode {
            case .tree:
                scaledBounds = scaledTreeBounds(from: node.bounds, direction: direction)
            case .diagram:
                let scaledSide = scaledDiagramNodeSide(
                    currentSide: node.bounds.width,
                    direction: direction
                )
                scaledBounds = Self.normalizedDiagramNodeBounds(
                    for: node,
                    proposedSide: scaledSide
                )
            }

            guard scaledBounds != node.bounds else {
                continue
            }

            let updatedNode = CanvasNode(
                id: node.id,
                kind: node.kind,
                text: node.text,
                attachments: node.attachments,
                bounds: scaledBounds,
                metadata: node.metadata,
                markdownStyleEnabled: node.markdownStyleEnabled
            )
            nextGraph = try CanvasGraphCRUDService.updateNode(updatedNode, in: nextGraph).get()
            didMutate = true
        }

        guard didMutate else {
            return noOpMutationResult(for: graph)
        }

        return CanvasMutationResult(
            graphBeforeMutation: graph,
            graphAfterMutation: nextGraph,
            effects: CanvasMutationEffects(
                didMutateGraph: true,
                needsTreeLayout: true,
                needsAreaLayout: true,
                needsFocusNormalization: false
            ),
            areaLayoutSeedNodeID: selectedNodeIDs.first
        )
    }
}

extension ApplyCanvasCommandsUseCase {
    private func selectedNodeIDsInFocusedArea(in graph: CanvasGraph) -> [CanvasNodeID] {
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

    private func scaledTreeBounds(
        from bounds: CanvasBounds,
        direction: CanvasNodeScaleDirection
    ) -> CanvasBounds {
        let directionSign = scaleDirectionSign(direction)
        let widthStep = CanvasDefaultNodeDistance.treeNodeWidth * CanvasDefaultNodeDistance.nodeScaleStepRatio
        let heightStep = CanvasDefaultNodeDistance.treeNodeHeight * CanvasDefaultNodeDistance.nodeScaleStepRatio
        let minimumWidth =
            CanvasDefaultNodeDistance.treeNodeWidth * CanvasDefaultNodeDistance.treeNodeMinimumWidthRatio
        let minimumHeight =
            CanvasDefaultNodeDistance.treeNodeHeight * CanvasDefaultNodeDistance.treeNodeMinimumHeightRatio
        let scaledWidth = max(bounds.width + (widthStep * directionSign), minimumWidth)
        let scaledHeight = max(bounds.height + (heightStep * directionSign), minimumHeight)
        return CanvasBounds(
            x: bounds.x,
            y: bounds.y,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    private func scaledDiagramNodeSide(
        currentSide: Double,
        direction: CanvasNodeScaleDirection
    ) -> Double {
        let directionSign = scaleDirectionSign(direction)
        let step = CanvasDefaultNodeDistance.diagramNodeSide * CanvasDefaultNodeDistance.nodeScaleStepRatio
        return max(
            currentSide + (step * directionSign),
            CanvasDefaultNodeDistance.diagramMinNodeSide
        )
    }

    private func scaleDirectionSign(_ direction: CanvasNodeScaleDirection) -> Double {
        switch direction {
        case .up:
            return 1
        case .down:
            return -1
        }
    }
}
