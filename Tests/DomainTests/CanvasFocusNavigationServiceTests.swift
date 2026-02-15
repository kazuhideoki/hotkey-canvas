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
            )
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
            )
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
