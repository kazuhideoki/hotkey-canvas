import Application
import Domain
import Testing

// Background: Directional focus movement is a core keyboard navigation behavior.
// Responsibility: Verify nearest-candidate selection and fallback focus rules.
@Test("moveFocus は要求された方向に最も近いノードを選択する")
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

@Test("moveFocus は、方向に候補がない場合でもフォーカスを維持する")
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

@Test("フォーカスが nil の場合、moveFocus は失敗する")
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

@Test("moveFocus はノード近くの大きくオフセットされたノードよりも整列したノードを優先する")
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

@Test("moveFocus は選択をフォーカス中のノードのみに更新する")
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

@Test("extendSelection は以前の選択を保持し、次にフォーカス中のノードを追加する")
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

@Test("moveFocus は方向に候補がない場合に選択を折りたたむ")
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

@Test("extendSelection には、選択が空の場合にフォーカス中のノードが含まれます")
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

@Test("エリアモードのmoveFocusは隣接するエリアにジャンプし、エリアフォーカスを維持する")
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

@Test("指向性エリアが存在しない場合、エリア モードの moveFocus は何もしない")
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

@Test("エリア モードの moveFocus は、指向性エリアが存在しない場合に再アンカーされない")
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
