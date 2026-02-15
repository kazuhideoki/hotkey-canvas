import Application
import Domain
import Testing

// Background: Directional focus movement is a core keyboard navigation behavior.
// Responsibility: Verify nearest-candidate selection and fallback focus rules.
@Test("ApplyCanvasCommandsUseCase: moveFocus picks nearest node in requested direction")
func test_apply_moveFocus_movesToNearestNodeInDirection() async throws {
    let centerID = CanvasNodeID(rawValue: "center")
    let rightNearID = CanvasNodeID(rawValue: "right-near")
    let rightFarID = CanvasNodeID(rawValue: "right-far")

    let graph = CanvasGraph(
        nodesByID: [
            centerID: CanvasNode(
                id: centerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            rightNearID: CanvasNode(
                id: rightNearID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 100, width: 100, height: 100)
            ),
            rightFarID: CanvasNode(
                id: rightFarID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 420, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: centerID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveFocus(.right)])

    #expect(result.newState.focusedNodeID == rightNearID)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus keeps focus when direction has no candidate")
func test_apply_moveFocus_keepsCurrentFocus_whenNoCandidateExists() async throws {
    let singleNodeID = CanvasNodeID(rawValue: "single")
    let graph = CanvasGraph(
        nodesByID: [
            singleNodeID: CanvasNode(
                id: singleNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: singleNodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveFocus(.left)])

    #expect(result.newState.focusedNodeID == singleNodeID)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus assigns fallback focus when focus is nil")
func test_apply_moveFocus_assignsFallbackFocus_whenFocusedNodeIDIsNil() async throws {
    let singleNodeID = CanvasNodeID(rawValue: "single")
    let graph = CanvasGraph(
        nodesByID: [
            singleNodeID: CanvasNode(
                id: singleNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nil
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveFocus(.left)])

    #expect(result.newState.focusedNodeID == singleNodeID)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus prefers aligned node over heavily offset near node")
func test_apply_moveFocus_prefersAlignedNode_overOffsetNearNode() async throws {
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
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.moveFocus(.right)])

    #expect(result.newState.focusedNodeID == rightAlignedFarID)
}
