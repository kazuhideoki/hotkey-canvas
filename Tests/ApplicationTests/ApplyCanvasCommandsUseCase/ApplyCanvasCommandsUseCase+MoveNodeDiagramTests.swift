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
