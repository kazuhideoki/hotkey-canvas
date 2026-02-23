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
