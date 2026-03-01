// Background: Directional navigation quality depends on balancing main-axis progress and cross-axis drift.
// Responsibility: Verify next focus selection in CanvasFocusNavigationService.
import Domain
import Testing

@Test("CanvasFocusNavigationService: picks aligned candidate over heavily offset nearer candidate")
func test_nextFocusedNodeID_prefersAlignedCandidate_overOffsetNearCandidate() {
    let centerID = CanvasNodeID(rawValue: "center")
    let rightOffsetNearID = CanvasNodeID(rawValue: "right-offset-near")
    let rightAlignedFarID = CanvasNodeID(rawValue: "right-aligned-far")
    let graph = CanvasGraph(
        nodesByID: [
            centerID: CanvasNode(
                id: centerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            rightOffsetNearID: CanvasNode(
                id: rightOffsetNearID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 180, y: 320, width: 100, height: 100)
            ),
            rightAlignedFarID: CanvasNode(
                id: rightAlignedFarID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 300, y: 100, width: 100, height: 100)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: centerID
    )

    let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(in: graph, moving: .right)

    #expect(nextFocusedNodeID == rightAlignedFarID)
}

@Test("CanvasFocusNavigationService: falls back to directional candidates when preferred corridor is empty")
func test_nextFocusedNodeID_usesDirectionalFallback_whenPreferredCorridorHasNoCandidate() {
    let centerID = CanvasNodeID(rawValue: "center")
    let upLeftID = CanvasNodeID(rawValue: "up-left")
    let upRightID = CanvasNodeID(rawValue: "up-right")
    let graph = CanvasGraph(
        nodesByID: [
            centerID: CanvasNode(
                id: centerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            upLeftID: CanvasNode(
                id: upLeftID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 20, width: 100, height: 100)
            ),
            upRightID: CanvasNode(
                id: upRightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 280, y: 0, width: 100, height: 100)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: centerID
    )

    let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(in: graph, moving: .up)

    #expect(nextFocusedNodeID == upLeftID)
}

@Test("CanvasFocusNavigationService: returns current focus when requested direction has no candidate")
func test_nextFocusedNodeID_returnsCurrentFocus_whenNoDirectionalCandidateExists() {
    let nodeID = CanvasNodeID(rawValue: "single")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )

    let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(in: graph, moving: .left)

    #expect(nextFocusedNodeID == nodeID)
}

@Test("CanvasFocusNavigationService: returns nil on empty graph")
func test_nextFocusedNodeID_returnsNil_whenGraphIsEmpty() {
    let nextFocusedNodeID = CanvasFocusNavigationService.nextFocusedNodeID(in: .empty, moving: .down)

    #expect(nextFocusedNodeID == nil)
}

@Test("CanvasFocusNavigationService: edge focus moves to nearest edge in requested direction")
func test_nextFocusedEdgeID_movesToNearestDirectionalEdge() {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let nodeDID = CanvasNodeID(rawValue: "node-d")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeCDID = CanvasEdgeID(rawValue: "edge-c-d")

    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 180, y: 0, width: 100, height: 80)
            ),
            nodeCID: CanvasNode(
                id: nodeCID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 200, width: 100, height: 80)
            ),
            nodeDID: CanvasNode(
                id: nodeDID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 180, y: 200, width: 100, height: 80)
            ),
        ],
        edgesByID: [
            edgeABID: CanvasEdge(id: edgeABID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
            edgeCDID: CanvasEdge(id: edgeCDID, fromNodeID: nodeCID, toNodeID: nodeDID, relationType: .normal),
        ]
    )

    let nextFocusedEdgeID = CanvasFocusNavigationService.nextFocusedEdgeID(
        in: graph,
        from: edgeABID,
        moving: .down
    )

    #expect(nextFocusedEdgeID == edgeCDID)
}

@Test("CanvasFocusNavigationService: edge focus cycles between duplicated coincident edges")
func test_nextFocusedEdgeID_withCoincidentEdges_cyclesByDirection() {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let edge1ID = CanvasEdgeID(rawValue: "edge-1")
    let edge2ID = CanvasEdgeID(rawValue: "edge-2")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 400, y: 0, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            edge1ID: CanvasEdge(id: edge1ID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
            edge2ID: CanvasEdge(id: edge2ID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
        ]
    )

    let nextByRight = CanvasFocusNavigationService.nextFocusedEdgeID(
        in: graph,
        from: edge1ID,
        moving: .right
    )
    let nextByLeft = CanvasFocusNavigationService.nextFocusedEdgeID(
        in: graph,
        from: edge1ID,
        moving: .left
    )

    #expect(nextByRight == edge2ID)
    #expect(nextByLeft == edge2ID)
}

@Test("CanvasFocusNavigationService: edge focus prioritizes duplicate bundle before directional candidates")
func test_nextFocusedEdgeID_prioritizesDuplicateBundle_beforeDirectionalCandidates() {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let nodeDID = CanvasNodeID(rawValue: "node-d")
    let edge1ID = CanvasEdgeID(rawValue: "edge-1")
    let edge2ID = CanvasEdgeID(rawValue: "edge-2")
    let edge3ID = CanvasEdgeID(rawValue: "edge-3")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 120)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 0, width: 120, height: 120)
            ),
            nodeCID: CanvasNode(
                id: nodeCID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 520, y: 0, width: 120, height: 120)
            ),
            nodeDID: CanvasNode(
                id: nodeDID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 760, y: 0, width: 120, height: 120)
            ),
        ],
        edgesByID: [
            edge1ID: CanvasEdge(id: edge1ID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
            edge2ID: CanvasEdge(id: edge2ID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
            edge3ID: CanvasEdge(id: edge3ID, fromNodeID: nodeCID, toNodeID: nodeDID, relationType: .normal),
        ]
    )

    let nextFocusedEdgeID = CanvasFocusNavigationService.nextFocusedEdgeID(
        in: graph,
        from: edge1ID,
        moving: .right
    )

    #expect(nextFocusedEdgeID == edge2ID)
}

@Test("CanvasFocusNavigationService: edge focus does not cycle to unrelated edge that only shares midpoint")
func test_nextFocusedEdgeID_doesNotCycleToUnrelatedEdge_whenOnlyMidpointMatches() {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let nodeDID = CanvasNodeID(rawValue: "node-d")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeCDID = CanvasEdgeID(rawValue: "edge-c-d")
    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: CanvasNode(
                id: nodeAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            ),
            nodeBID: CanvasNode(
                id: nodeBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            nodeCID: CanvasNode(
                id: nodeCID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 100, width: 100, height: 100)
            ),
            nodeDID: CanvasNode(
                id: nodeDID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 0, width: 100, height: 100)
            ),
        ],
        edgesByID: [
            edgeABID: CanvasEdge(id: edgeABID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
            edgeCDID: CanvasEdge(id: edgeCDID, fromNodeID: nodeCID, toNodeID: nodeDID, relationType: .normal),
        ]
    )

    let nextFocusedEdgeID = CanvasFocusNavigationService.nextFocusedEdgeID(
        in: graph,
        from: edgeABID,
        moving: .right
    )

    #expect(nextFocusedEdgeID == edgeABID)
}
