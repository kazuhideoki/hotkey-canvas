import Application
import Domain
import Testing

// Background: Tree roots should remain immutable by move-node commands even when diagram areas coexist.
// Responsibility: Verify tree-root move isolation from diagram areas.
@Test("ApplyCanvasCommandsUseCase: moveNode up does not move top-level tree root when diagram area exists")
func test_apply_moveNodeUp_doesNotMoveTopLevelTreeRootWithDiagramArea() async throws {
    let treeRootID = CanvasNodeID(rawValue: "tree-root")
    let treeChildID = CanvasNodeID(rawValue: "tree-child")
    let diagramRootID = CanvasNodeID(rawValue: "diagram-root")

    let treeAreaID = CanvasAreaID(rawValue: "area-tree")
    let diagramAreaID = CanvasAreaID(rawValue: "area-diagram")

    let treeRoot = CanvasNode(
        id: treeRootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
    )
    let treeChild = CanvasNode(
        id: treeChildID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 260, y: 0, width: 220, height: 120)
    )
    let diagramRoot = CanvasNode(
        id: diagramRootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 800, y: 0, width: 220, height: 220)
    )

    let treeEdge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-tree-root-child"),
        fromNodeID: treeRootID,
        toNodeID: treeChildID,
        relationType: .parentChild
    )

    let graph = CanvasGraph(
        nodesByID: [
            treeRootID: treeRoot,
            treeChildID: treeChild,
            diagramRootID: diagramRoot,
        ],
        edgesByID: [treeEdge.id: treeEdge],
        focusedNodeID: treeRootID,
        areasByID: [
            treeAreaID: CanvasArea(id: treeAreaID, nodeIDs: [treeRootID, treeChildID], editingMode: .tree),
            diagramAreaID: CanvasArea(id: diagramAreaID, nodeIDs: [diagramRootID], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.up)])

    #expect(result.newState == graph)
    #expect(containsParentChildEdge(from: treeRootID, to: treeChildID, in: result.newState))
    #expect(containsParentChildEdge(from: diagramRootID, to: treeRootID, in: result.newState) == false)
}

private func containsParentChildEdge(
    from parentID: CanvasNodeID,
    to childID: CanvasNodeID,
    in graph: CanvasGraph
) -> Bool {
    graph.edgesByID.values.contains {
        $0.relationType == .parentChild
            && $0.fromNodeID == parentID
            && $0.toNodeID == childID
    }
}
