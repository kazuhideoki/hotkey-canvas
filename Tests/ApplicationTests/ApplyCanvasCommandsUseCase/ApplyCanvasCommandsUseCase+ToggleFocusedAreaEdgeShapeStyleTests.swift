import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: toggleFocusedAreaEdgeShapeStyle cycles focused area edge shape style")
func test_apply_toggleFocusedAreaEdgeShapeStyle_cyclesFocusedAreaEdgeShapeStyle() async throws {
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
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree, edgeShapeStyle: .legacy)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let firstToggle = try await sut.apply(commands: [.toggleFocusedAreaEdgeShapeStyle])
    #expect(firstToggle.newState.areasByID[areaID]?.edgeShapeStyle == .curved)

    let secondToggle = try await sut.apply(commands: [.toggleFocusedAreaEdgeShapeStyle])
    #expect(secondToggle.newState.areasByID[areaID]?.edgeShapeStyle == .straight)

    let thirdToggle = try await sut.apply(commands: [.toggleFocusedAreaEdgeShapeStyle])
    #expect(thirdToggle.newState.areasByID[areaID]?.edgeShapeStyle == .legacy)
}
