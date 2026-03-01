import Application
import Domain
import Testing

// Background: Area target mode introduces explicit area focus independent from node/edge focus.
// Responsibility: Verify focusArea command updates area focus, node anchor, and no-op guards.
@Test("ApplyCanvasCommandsUseCase: focusArea focuses area and picks top-left visible anchor")
func test_apply_focusArea_setsAreaFocusAndAnchor() async throws {
    let leftNodeID = CanvasNodeID(rawValue: "left")
    let rightNodeID = CanvasNodeID(rawValue: "right")
    let targetTopID = CanvasNodeID(rawValue: "target-top")
    let targetLowerID = CanvasNodeID(rawValue: "target-lower")
    let selectedEdgeID = CanvasEdgeID(rawValue: "selected-edge")
    let sourceAreaID = CanvasAreaID(rawValue: "source-area")
    let targetAreaID = CanvasAreaID(rawValue: "target-area")

    let graph = CanvasGraph(
        nodesByID: [
            leftNodeID: CanvasNode(
                id: leftNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            rightNodeID: CanvasNode(
                id: rightNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 160, y: 0, width: 100, height: 80)
            ),
            targetTopID: CanvasNode(
                id: targetTopID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 520, y: 40, width: 100, height: 80)
            ),
            targetLowerID: CanvasNode(
                id: targetLowerID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 500, y: 220, width: 100, height: 80)
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
        selectedNodeIDs: [leftNodeID, rightNodeID],
        selectedEdgeIDs: [selectedEdgeID],
        areasByID: [
            sourceAreaID: CanvasArea(id: sourceAreaID, nodeIDs: [leftNodeID, rightNodeID], editingMode: .diagram),
            targetAreaID: CanvasArea(id: targetAreaID, nodeIDs: [targetTopID, targetLowerID], editingMode: .diagram),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let commands: [CanvasCommand] = [.focusArea(targetAreaID)]
    let result = try await sut.apply(commands: commands)

    #expect(result.newState.focusedElement == .area(targetAreaID))
    #expect(result.newState.focusedNodeID == targetTopID)
    #expect(result.newState.selectedNodeIDs == [targetTopID])
    #expect(result.newState.selectedEdgeIDs.isEmpty)
}

@Test("ApplyCanvasCommandsUseCase: focusArea fails when area does not exist")
func test_apply_focusArea_failsWhenAreaMissing() async throws {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let sourceAreaID = CanvasAreaID(rawValue: "source-area")
    let missingAreaID = CanvasAreaID(rawValue: "missing-area")
    let graph = CanvasGraph(
        nodesByID: [
            focusedNodeID: CanvasNode(
                id: focusedNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            )
        ],
        edgesByID: [:],
        focusedNodeID: focusedNodeID,
        selectedNodeIDs: [focusedNodeID],
        areasByID: [
            sourceAreaID: CanvasArea(id: sourceAreaID, nodeIDs: [focusedNodeID], editingMode: .tree)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let commands: [CanvasCommand] = [.focusArea(missingAreaID)]
    do {
        _ = try await sut.apply(commands: commands)
        Issue.record("Expected areaNotFound")
    } catch let error as CanvasAreaPolicyError {
        #expect(error == .areaNotFound(missingAreaID))
    }
}

@Test("ApplyCanvasCommandsUseCase: focusArea is no-op when area has no visible anchor")
func test_apply_focusArea_noOpWhenAreaHasNoVisibleAnchor() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let hiddenChildID = CanvasNodeID(rawValue: "hidden-child")
    let rootAreaID = CanvasAreaID(rawValue: "root-area")
    let hiddenAreaID = CanvasAreaID(rawValue: "hidden-area")
    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 40, y: 40, width: 200, height: 100)
            ),
            hiddenChildID: CanvasNode(
                id: hiddenChildID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 300, y: 40, width: 200, height: 100)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: hiddenChildID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID,
        focusedElement: .node(rootID),
        selectedNodeIDs: [rootID],
        collapsedRootNodeIDs: [rootID],
        areasByID: [
            rootAreaID: CanvasArea(id: rootAreaID, nodeIDs: [rootID], editingMode: .tree),
            hiddenAreaID: CanvasArea(id: hiddenAreaID, nodeIDs: [hiddenChildID], editingMode: .tree),
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let commands: [CanvasCommand] = [.focusArea(hiddenAreaID)]
    let result = try await sut.apply(commands: commands)

    #expect(result.newState == graph)
    #expect(!result.canUndo)
}
