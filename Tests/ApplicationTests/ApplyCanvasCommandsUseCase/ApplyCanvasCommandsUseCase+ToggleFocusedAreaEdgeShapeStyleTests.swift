import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: toggleFocusedAreaEdgeShapeStyle toggles focused area edge shape style")
func test_apply_toggleFocusedAreaEdgeShapeStyle_togglesFocusedAreaEdgeShapeStyle() async throws {
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
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree, edgeShapeStyle: .curved)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let firstToggle = try await sut.apply(commands: [.toggleFocusedAreaEdgeShapeStyle])
    #expect(firstToggle.newState.areasByID[areaID]?.edgeShapeStyle == .straight)

    let secondToggle = try await sut.apply(commands: [.toggleFocusedAreaEdgeShapeStyle])
    #expect(secondToggle.newState.areasByID[areaID]?.edgeShapeStyle == .curved)
}
