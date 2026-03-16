// 背景: Diagram node move では複数選択を 1 つの非凸 cluster として扱う衝突解消が必要。
// 責務: diagram 用 collision body を組み立て、伝播した移動量を graph node へ反映する。
import Domain

extension CanvasCommandPipelineCoordinator {
    func runDiagramNodeLayoutStage(
        on graph: CanvasGraph,
        seedNodeIDs: Set<CanvasNodeID>,
        seedMoveDirection: CanvasNodeMoveDirection?,
        in seedArea: CanvasArea
    ) -> CanvasGraph {
        let nodeIDs = seedArea.nodeIDs
            .filter { graph.nodesByID[$0] != nil }
            .sorted { $0.rawValue < $1.rawValue }
        guard nodeIDs.count > 1 else {
            return graph
        }

        let collisionBodies = diagramCollisionBodies(
            nodeIDs: nodeIDs,
            seedNodeIDs: seedNodeIDs,
            in: graph
        )
        guard collisionBodies.count > 1 else {
            return graph
        }
        guard let seedBodyID = diagramCollisionSeedBodyID(seedNodeIDs: seedNodeIDs) else {
            return graph
        }

        let translationsByBodyID = CanvasCollisionResolutionService.resolveOverlaps(
            bodies: collisionBodies,
            seedBodyID: seedBodyID,
            minimumSpacing: 16,
            seedPreferredMoveDirection: seedMoveDirection
        )
        return applyingCollisionBodyTranslations(
            to: graph,
            bodies: collisionBodies,
            translationsByBodyID: translationsByBodyID
        )
    }

    private func diagramCollisionBodies(
        nodeIDs: [CanvasNodeID],
        seedNodeIDs: Set<CanvasNodeID>,
        in graph: CanvasGraph
    ) -> [CanvasCollisionBody] {
        let existingSeedNodeIDs =
            seedNodeIDs
            .filter { graph.nodesByID[$0] != nil }
        guard existingSeedNodeIDs.isEmpty == false else {
            return nodeIDs.compactMap { nodeID in
                diagramCollisionBody(
                    bodyID: .node(nodeID),
                    nodeIDs: [nodeID],
                    in: graph
                )
            }
        }

        var bodies: [CanvasCollisionBody] = []
        if let seedBodyID = diagramCollisionSeedBodyID(seedNodeIDs: existingSeedNodeIDs),
            let seedBody = diagramCollisionBody(
                bodyID: seedBodyID,
                nodeIDs: existingSeedNodeIDs,
                in: graph
            )
        {
            bodies.append(seedBody)
        }

        for nodeID in nodeIDs where existingSeedNodeIDs.contains(nodeID) == false {
            guard
                let body = diagramCollisionBody(
                    bodyID: .node(nodeID),
                    nodeIDs: [nodeID],
                    in: graph
                )
            else {
                continue
            }
            bodies.append(body)
        }

        return bodies
    }

    private func diagramCollisionSeedBodyID(seedNodeIDs: Set<CanvasNodeID>) -> CanvasCollisionBodyID? {
        let sortedSeedNodeIDs = seedNodeIDs.sorted { $0.rawValue < $1.rawValue }
        guard let firstSeedNodeID = sortedSeedNodeIDs.first else {
            return nil
        }
        guard sortedSeedNodeIDs.count > 1 else {
            return .node(firstSeedNodeID)
        }
        return .cluster(nodeIDs: sortedSeedNodeIDs)
    }

    private func diagramCollisionBody(
        bodyID: CanvasCollisionBodyID,
        nodeIDs: Set<CanvasNodeID>,
        in graph: CanvasGraph
    ) -> CanvasCollisionBody? {
        let sortedRects =
            nodeIDs
            .sorted { $0.rawValue < $1.rawValue }
            .compactMap { nodeID -> CanvasRect? in
                guard let node = graph.nodesByID[nodeID] else {
                    return nil
                }
                return CanvasRect(
                    minX: node.bounds.x,
                    minY: node.bounds.y,
                    width: node.bounds.width,
                    height: node.bounds.height
                )
            }
        guard let firstRect = sortedRects.first else {
            return nil
        }

        let shape =
            if sortedRects.count == 1 {
                CanvasCollisionShape(rect: firstRect)
            } else {
                CanvasCollisionShape(rects: sortedRects)
            }
        return CanvasCollisionBody(
            id: bodyID,
            nodeIDs: nodeIDs,
            shape: shape
        )
    }

    private func applyingCollisionBodyTranslations(
        to graph: CanvasGraph,
        bodies: [CanvasCollisionBody],
        translationsByBodyID: [CanvasCollisionBodyID: CanvasTranslation]
    ) -> CanvasGraph {
        guard translationsByBodyID.isEmpty == false else {
            return graph
        }

        let bodiesByID = Dictionary(uniqueKeysWithValues: bodies.map { ($0.id, $0) })
        var nodesByID = graph.nodesByID

        for bodyID in translationsByBodyID.keys.sorted(by: compareBodyID) {
            guard let translation = translationsByBodyID[bodyID] else {
                continue
            }
            guard let body = bodiesByID[bodyID] else {
                continue
            }

            for nodeID in body.nodeIDs.sorted(by: { $0.rawValue < $1.rawValue }) {
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

    private func compareBodyID(_ lhs: CanvasCollisionBodyID, _ rhs: CanvasCollisionBodyID) -> Bool {
        switch (lhs, rhs) {
        case (.node(let lhsNodeID), .node(let rhsNodeID)):
            return lhsNodeID.rawValue < rhsNodeID.rawValue
        case (.node, .cluster):
            return true
        case (.cluster, .node):
            return false
        case (.cluster(let lhsNodeIDs), .cluster(let rhsNodeIDs)):
            return lhsNodeIDs.map(\.rawValue).joined(separator: ",")
                < rhsNodeIDs.map(\.rawValue).joined(separator: ",")
        }
    }
}
