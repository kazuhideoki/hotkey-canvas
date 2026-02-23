import Application
import Domain
import Testing

// Background: Diagram moveNode uses semantic slot movement and should resolve collisions immediately.
// Responsibility: Verify moveNode overlap resolution behavior inside one diagram area.
@Test("ApplyCanvasCommandsUseCase: moveNode in diagram area resolves overlap within same area")
func test_apply_moveNodeInDiagramArea_resolvesOverlapWithinSameArea() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let anchorID = CanvasNodeID(rawValue: "anchor")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let blockerID = CanvasNodeID(rawValue: "blocker")
    let edgeID = CanvasEdgeID(rawValue: "edge-anchor-focused")

    let anchor = CanvasNode(
        id: anchorID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
    )
    let focused = CanvasNode(
        id: focusedID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 300, y: 0, width: 220, height: 220)
    )
    let blocker = CanvasNode(
        id: blockerID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 0, y: 440, width: 220, height: 220)
    )
    let edge = CanvasEdge(
        id: edgeID,
        fromNodeID: anchorID,
        toNodeID: focusedID,
        relationType: .normal
    )
    let graph = CanvasGraph(
        nodesByID: [
            anchorID: anchor,
            focusedID: focused,
            blockerID: blocker,
        ],
        edgesByID: [edgeID: edge],
        focusedNodeID: focusedID,
        areasByID: [
            areaID: CanvasArea(
                id: areaID,
                nodeIDs: [anchorID, focusedID, blockerID],
                editingMode: .diagram
            )
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.down)])

    let focusedAfter = try #require(result.newState.nodesByID[focusedID])
    let blockerAfter = try #require(result.newState.nodesByID[blockerID])
    #expect(boundsOverlap(focusedAfter.bounds, blockerAfter.bounds, spacing: 0) == false)
}

@Test("ApplyCanvasCommandsUseCase: moveNode in diagram area moves focused node without anchor")
func test_apply_moveNodeInDiagramArea_movesFocusedNodeWithoutAnchor() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            )
        ],
        focusedNodeID: focusedID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.right)])

    let movedNode = try #require(result.newState.nodesByID[focusedID])
    #expect(movedNode.bounds.x == 440)
    #expect(movedNode.bounds.y == 0)
}

@Test("ApplyCanvasCommandsUseCase: moveNode in diagram area moves unconnected focused node")
func test_apply_moveNodeInDiagramArea_movesUnconnectedFocusedNode() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let otherID = CanvasNodeID(rawValue: "other")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            otherID: CanvasNode(
                id: otherID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 2000, y: 0, width: 220, height: 220)
            ),
        ],
        focusedNodeID: focusedID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedID, otherID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.down)])

    let movedNode = try #require(result.newState.nodesByID[focusedID])
    #expect(movedNode.bounds.x == 0)
    #expect(movedNode.bounds.y == 440)
}

@Test("ApplyCanvasCommandsUseCase: moveNode in diagram area keeps moving by grid slots from current position")
func test_apply_moveNodeInDiagramArea_movesByGridFromCurrentPosition() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let anchorID = CanvasNodeID(rawValue: "anchor")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let edgeID = CanvasEdgeID(rawValue: "edge-anchor-focused")
    let graph = CanvasGraph(
        nodesByID: [
            anchorID: CanvasNode(
                id: anchorID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 440, y: 0, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: anchorID,
                toNodeID: focusedID,
                relationType: .normal
            )
        ],
        focusedNodeID: focusedID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [anchorID, focusedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.right)])

    let movedNode = try #require(result.newState.nodesByID[focusedID])
    #expect(movedNode.bounds.x == 880)
    #expect(movedNode.bounds.y == 0)
}

@Test("ApplyCanvasCommandsUseCase: moveNode in diagram area uses current-slot direction")
func test_apply_moveNodeInDiagramArea_movesRelativeToCurrentSlotDirection() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let anchorID = CanvasNodeID(rawValue: "anchor")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let edgeID = CanvasEdgeID(rawValue: "edge-anchor-focused")
    let graph = CanvasGraph(
        nodesByID: [
            anchorID: CanvasNode(
                id: anchorID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 440, y: -440, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: anchorID,
                toNodeID: focusedID,
                relationType: .normal
            )
        ],
        focusedNodeID: focusedID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [anchorID, focusedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.left)])

    let movedNode = try #require(result.newState.nodesByID[focusedID])
    #expect(movedNode.bounds.x == 0)
    #expect(movedNode.bounds.y == -440)
}

@Test("ApplyCanvasCommandsUseCase: moveNode in diagram area skips candidate that overlaps anchor")
func test_apply_moveNodeInDiagramArea_skipsAnchorOverlappingCandidate() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let anchorID = CanvasNodeID(rawValue: "anchor")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let edgeID = CanvasEdgeID(rawValue: "edge-anchor-focused")
    let graph = CanvasGraph(
        nodesByID: [
            anchorID: CanvasNode(
                id: anchorID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: -300, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: anchorID,
                toNodeID: focusedID,
                relationType: .normal
            )
        ],
        focusedNodeID: focusedID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [anchorID, focusedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.down)])

    let movedNode = try #require(result.newState.nodesByID[focusedID])
    let anchorNode = try #require(graph.nodesByID[anchorID])
    #expect(boundsOverlap(movedNode.bounds, anchorNode.bounds) == false)
    #expect(movedNode.bounds.x == 0)
    #expect(movedNode.bounds.y == 580)
}

@Test("ApplyCanvasCommandsUseCase: moveNode in diagram area does not drift diagonally after nudge")
func test_apply_moveNodeInDiagramArea_noDiagonalDriftAfterNudge() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let anchorID = CanvasNodeID(rawValue: "anchor")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let edgeID = CanvasEdgeID(rawValue: "edge-anchor-focused")
    let graph = CanvasGraph(
        nodesByID: [
            anchorID: CanvasNode(
                id: anchorID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 440, y: -440, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: anchorID,
                toNodeID: focusedID,
                relationType: .normal
            )
        ],
        focusedNodeID: focusedID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [anchorID, focusedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let nudged = try await sut.apply(commands: [.nudgeNode(.down)])
    let nudgedNode = try #require(nudged.newState.nodesByID[focusedID])
    let moved = try await ApplyCanvasCommandsUseCase(initialGraph: nudged.newState)
        .apply(commands: [.moveNode(.left)])

    let movedNode = try #require(moved.newState.nodesByID[focusedID])
    #expect(movedNode.bounds.x == 0)
    #expect(abs(movedNode.bounds.y - nudgedNode.bounds.y) <= 20)
}

@Test("ApplyCanvasCommandsUseCase: diagram nudge step keeps 4:1 ratio against move step")
func test_apply_moveNodeInDiagramArea_nudgeStepIsQuarterOfMoveStep() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            )
        ],
        focusedNodeID: focusedID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedID], editingMode: .diagram)
        ]
    )

    let moved = try await ApplyCanvasCommandsUseCase(initialGraph: graph).apply(commands: [.moveNode(.right)])
    let nudged = try await ApplyCanvasCommandsUseCase(initialGraph: graph).apply(commands: [.nudgeNode(.right)])

    let movedNode = try #require(moved.newState.nodesByID[focusedID])
    let nudgedNode = try #require(nudged.newState.nodesByID[focusedID])
    let moveDelta = movedNode.bounds.x - 0
    let nudgeDelta = nudgedNode.bounds.x - 0
    #expect(moveDelta == 440)
    #expect(nudgeDelta == 110)
    #expect(moveDelta == nudgeDelta * 4)
}

@Test("ApplyCanvasCommandsUseCase: moveNode in diagram area translates selected nodes together")
func test_apply_moveNodeInDiagramArea_multiSelection_translatesAsGroup() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let anchorID = CanvasNodeID(rawValue: "anchor")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let selectedID = CanvasNodeID(rawValue: "selected")
    let edgeID = CanvasEdgeID(rawValue: "edge-anchor-focused")
    let graph = CanvasGraph(
        nodesByID: [
            anchorID: CanvasNode(
                id: anchorID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 440, y: 0, width: 220, height: 220)
            ),
            selectedID: CanvasNode(
                id: selectedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 900, y: 110, width: 220, height: 220)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: anchorID,
                toNodeID: focusedID,
                relationType: .normal
            )
        ],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [anchorID, focusedID, selectedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.right)])

    let focusedAfter = try #require(result.newState.nodesByID[focusedID])
    let selectedAfter = try #require(result.newState.nodesByID[selectedID])
    #expect(focusedAfter.bounds.x == 880)
    #expect(focusedAfter.bounds.y == 0)
    #expect(selectedAfter.bounds.x == 1340)
    #expect(selectedAfter.bounds.y == 110)
}

@Test("ApplyCanvasCommandsUseCase: nudgeNode in diagram area translates selected nodes together")
func test_apply_nudgeNodeInDiagramArea_multiSelection_translatesAsGroup() async throws {
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let selectedID = CanvasNodeID(rawValue: "selected")
    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            ),
            selectedID: CanvasNode(
                id: selectedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 330, y: -120, width: 220, height: 220)
            ),
        ],
        focusedNodeID: focusedID,
        selectedNodeIDs: [focusedID, selectedID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [focusedID, selectedID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.nudgeNode(.down)])

    let focusedAfter = try #require(result.newState.nodesByID[focusedID])
    let selectedAfter = try #require(result.newState.nodesByID[selectedID])
    #expect(focusedAfter.bounds.y == 110)
    #expect(selectedAfter.bounds.y == -10)
    #expect(focusedAfter.bounds.x == 0)
    #expect(selectedAfter.bounds.x == 330)
}

private func boundsOverlap(_ lhs: CanvasBounds, _ rhs: CanvasBounds, spacing: Double = 0) -> Bool {
    let halfSpacing = max(0, spacing) / 2
    let lhsLeft = lhs.x - halfSpacing
    let lhsTop = lhs.y - halfSpacing
    let lhsRight = lhs.x + lhs.width + halfSpacing
    let lhsBottom = lhs.y + lhs.height + halfSpacing
    let rhsLeft = rhs.x - halfSpacing
    let rhsTop = rhs.y - halfSpacing
    let rhsRight = rhs.x + rhs.width + halfSpacing
    let rhsBottom = rhs.y + rhs.height + halfSpacing

    return lhsLeft < rhsRight
        && lhsRight > rhsLeft
        && lhsTop < rhsBottom
        && lhsBottom > rhsTop
}
