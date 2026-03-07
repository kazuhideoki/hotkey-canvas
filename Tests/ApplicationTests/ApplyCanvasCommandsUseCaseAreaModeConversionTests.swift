import Application
import Domain
import Testing

// Background: Focused area mode conversion must update area mode and reshape focused diagram node bounds.
// Responsibility: Verify focused-area mode conversion succeeds through the apply pipeline.
@Test("ApplyCanvasCommandsUseCase: convertFocusedAreaMode converts focused area mode")
func test_apply_convertFocusedAreaMode_convertsFocusedAreaMode() async throws {
    let nodeID = CanvasNodeID(rawValue: "focused")
    let areaID = CanvasAreaID(rawValue: "area-1")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.convertFocusedAreaMode(to: .diagram)])

    #expect(result.newState.areasByID[areaID]?.editingMode == .diagram)
    let convertedNode = try #require(result.newState.nodesByID[nodeID])
    #expect(convertedNode.bounds.width == 220)
    #expect(convertedNode.bounds.height == 220)
}
