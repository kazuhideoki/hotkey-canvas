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
            ),
        ],
        edgesByID: [:],
        focusedNodeID: centerID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

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
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveFocus(.left)])

    #expect(result.newState.focusedNodeID == singleNodeID)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus fails when focus is nil")
func test_apply_moveFocus_fails_whenFocusedNodeIDIsNil() async throws {
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
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    do {
        _ = try await sut.apply(commands: [.moveFocus(.left)])
        Issue.record("Expected focusedNodeNotFound")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .focusedNodeNotFound)
    }
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
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveFocus(.right)])

    #expect(result.newState.focusedNodeID == rightAlignedFarID)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus updates selection to focused node only")
func test_apply_moveFocus_updatesSelectionToFocusedNodeOnly() async throws {
    let centerID = CanvasNodeID(rawValue: "center")
    let rightID = CanvasNodeID(rawValue: "right")
    let graph = CanvasGraph(
        nodesByID: [
            centerID: CanvasNode(
                id: centerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            rightID: CanvasNode(
                id: rightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 100, width: 100, height: 100)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: centerID,
        selectedNodeIDs: [centerID, rightID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveFocus(.right)])

    #expect(result.newState.focusedNodeID == rightID)
    #expect(result.newState.selectedNodeIDs == [rightID])
}

@Test("ApplyCanvasCommandsUseCase: extendSelection keeps previous selection and adds next focused node")
func test_apply_extendSelection_addsNextFocusedNode() async throws {
    let centerID = CanvasNodeID(rawValue: "center")
    let rightID = CanvasNodeID(rawValue: "right")
    let graph = CanvasGraph(
        nodesByID: [
            centerID: CanvasNode(
                id: centerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            rightID: CanvasNode(
                id: rightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 100, width: 100, height: 100)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: centerID,
        selectedNodeIDs: [centerID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.extendSelection(.right)])

    #expect(result.newState.focusedNodeID == rightID)
    #expect(result.newState.selectedNodeIDs == [centerID, rightID])
}

@Test("ApplyCanvasCommandsUseCase: moveFocus collapses selection when direction has no candidate")
func test_apply_moveFocus_collapsesSelection_whenDirectionHasNoCandidate() async throws {
    let centerID = CanvasNodeID(rawValue: "center")
    let rightID = CanvasNodeID(rawValue: "right")
    let graph = CanvasGraph(
        nodesByID: [
            centerID: CanvasNode(
                id: centerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            rightID: CanvasNode(
                id: rightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 100, width: 100, height: 100)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: centerID,
        selectedNodeIDs: [centerID, rightID]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.moveFocus(.left)])

    #expect(result.newState.focusedNodeID == centerID)
    #expect(result.newState.selectedNodeIDs == [centerID])
}

@Test("ApplyCanvasCommandsUseCase: extendSelection includes focused node when selection is empty")
func test_apply_extendSelection_includesFocusedNode_whenSelectionIsEmpty() async throws {
    let centerID = CanvasNodeID(rawValue: "center")
    let rightID = CanvasNodeID(rawValue: "right")
    let graph = CanvasGraph(
        nodesByID: [
            centerID: CanvasNode(
                id: centerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 100)
            ),
            rightID: CanvasNode(
                id: rightID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 240, y: 100, width: 100, height: 100)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: centerID,
        selectedNodeIDs: []
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let result = try await sut.apply(commands: [.extendSelection(.right)])

    #expect(result.newState.focusedNodeID == rightID)
    #expect(result.newState.selectedNodeIDs == [centerID, rightID])
}

@Test("ApplyCanvasCommandsUseCase: moveFocus in area mode jumps to adjacent area and keeps area focus")
func test_apply_moveFocus_areaMode_movesAreaFocusAndAnchor() async throws {
    let leftNodeID = CanvasNodeID(rawValue: "left")
    let rightNodeID = CanvasNodeID(rawValue: "right")
    let selectedEdgeID = CanvasEdgeID(rawValue: "selected-edge")
    let leftAreaID = CanvasAreaID(rawValue: "left-area")
    let rightAreaID = CanvasAreaID(rawValue: "right-area")
    let graph = CanvasGraph(
        nodesByID: [
            leftNodeID: CanvasNode(
                id: leftNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 120, height: 80)
            ),
            rightNodeID: CanvasNode(
                id: rightNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 420, y: 0, width: 120, height: 80)
            ),
        ],
        edgesByID: [
            selectedEdgeID: CanvasEdge(
                id: selectedEdgeID,
                fromNodeID: leftNodeID,
                toNodeID: rightNodeID,
                relationType: .normal
            )
        ],
        focusedNodeID: leftNodeID,
        focusedElement: .area(leftAreaID),
        selectedNodeIDs: [leftNodeID],
        selectedEdgeIDs: [selectedEdgeID],
        areasByID: [
            leftAreaID: CanvasArea(id: leftAreaID, nodeIDs: [leftNodeID], editingMode: .diagram),
            rightAreaID: CanvasArea(id: rightAreaID, nodeIDs: [rightNodeID], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let commands: [CanvasCommand] = [.moveFocus(.right)]
    let result = try await sut.apply(commands: commands)

    #expect(result.newState.focusedElement == .area(rightAreaID))
    #expect(result.newState.focusedNodeID == rightNodeID)
    #expect(result.newState.selectedNodeIDs == [rightNodeID])
    #expect(result.newState.selectedEdgeIDs.isEmpty)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus in area mode is no-op when no directional area exists")
func test_apply_moveFocus_areaMode_noOpWhenNoDirectionalArea() async throws {
    let singleNodeID = CanvasNodeID(rawValue: "single")
    let singleAreaID = CanvasAreaID(rawValue: "single-area")
    let graph = CanvasGraph(
        nodesByID: [
            singleNodeID: CanvasNode(
                id: singleNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: singleNodeID,
        focusedElement: .area(singleAreaID),
        selectedNodeIDs: [singleNodeID],
        areasByID: [
            singleAreaID: CanvasArea(id: singleAreaID, nodeIDs: [singleNodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let commands: [CanvasCommand] = [.moveFocus(.left)]
    let result = try await sut.apply(commands: commands)

    #expect(result.newState == graph)
    #expect(!result.canUndo)
}

@Test("ApplyCanvasCommandsUseCase: moveFocus in area mode does not re-anchor when no directional area exists")
func test_apply_moveFocus_areaMode_doesNotReanchorWithinSameAreaWithoutDirectionalCandidate() async throws {
    let anchorNodeID = CanvasNodeID(rawValue: "anchor")
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let areaID = CanvasAreaID(rawValue: "area")
    let graph = CanvasGraph(
        nodesByID: [
            anchorNodeID: CanvasNode(
                id: anchorNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 220, y: 220, width: 100, height: 80)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID,
        focusedElement: .area(areaID),
        selectedNodeIDs: [focusedNodeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [anchorNodeID, focusedNodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let commands: [CanvasCommand] = [.moveFocus(.left)]
    let result = try await sut.apply(commands: commands)

    #expect(result.newState == graph)
    #expect(!result.canUndo)
}
