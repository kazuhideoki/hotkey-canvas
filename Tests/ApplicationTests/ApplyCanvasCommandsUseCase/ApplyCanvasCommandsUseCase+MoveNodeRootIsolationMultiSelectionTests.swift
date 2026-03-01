import Application
import Domain
import Testing

// Background: Top-level tree roots must not move even when moveNode is invoked through multi-selection paths.
// Responsibility: Ensure multi-selection up/down commands keep root structure unchanged.
@Test("ApplyCanvasCommandsUseCase: moveNode down is no-op for top-level root in multi-selection")
func test_apply_moveNodeDown_topLevelRootMultiSelection_isNoOp() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let rootChildID = CanvasNodeID(rawValue: "root-child")
    let siblingRootID = CanvasNodeID(rawValue: "sibling-root")

    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            ),
            rootChildID: CanvasNode(
                id: rootChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 260, y: 0, width: 220, height: 120)
            ),
            siblingRootID: CanvasNode(
                id: siblingRootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 220, width: 220, height: 120)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: rootChildID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID,
        selectedNodeIDs: [rootID, rootChildID]
    ).withDefaultTreeAreaIfMissing()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveNode(.down)])

    #expect(result.newState == graph)
}
