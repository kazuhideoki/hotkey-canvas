import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode focuses upper sibling first")
func test_apply_deleteFocusedNode_focusesUpperSibling_whenSiblingExists() async throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let upperSiblingID = CanvasNodeID(rawValue: "upper-sibling")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let lowerSiblingID = CanvasNodeID(rawValue: "lower-sibling")

    let graph = CanvasGraph(
        nodesByID: [
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            upperSiblingID: CanvasNode(
                id: upperSiblingID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 120, width: 100, height: 80)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 240, width: 100, height: 80)
            ),
            lowerSiblingID: CanvasNode(
                id: lowerSiblingID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 360, width: 100, height: 80)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-parent-upper"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-upper"),
                fromNodeID: parentID,
                toNodeID: upperSiblingID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-parent-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-focused"),
                fromNodeID: parentID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-parent-lower"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-lower"),
                fromNodeID: parentID,
                toNodeID: lowerSiblingID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[focusedID] == nil)
    #expect(result.newState.focusedNodeID == upperSiblingID)
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode focuses parent when no sibling exists")
func test_apply_deleteFocusedNode_focusesParent_whenSiblingDoesNotExist() async throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let nearbyNodeID = CanvasNodeID(rawValue: "nearby")

    let graph = CanvasGraph(
        nodesByID: [
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 200, width: 100, height: 80)
            ),
            nearbyNodeID: CanvasNode(
                id: nearbyNodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 320, y: 220, width: 100, height: 80)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-parent-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-focused"),
                fromNodeID: parentID,
                toNodeID: focusedID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[focusedID] == nil)
    #expect(result.newState.focusedNodeID == parentID)
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode focuses nearest node when parent does not exist")
func test_apply_deleteFocusedNode_focusesNearestNode_whenParentDoesNotExist() async throws {
    let focusedID = CanvasNodeID(rawValue: "focused")
    let nearestID = CanvasNodeID(rawValue: "nearest")
    let farID = CanvasNodeID(rawValue: "far")

    let graph = CanvasGraph(
        nodesByID: [
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 100, width: 100, height: 80)
            ),
            nearestID: CanvasNode(
                id: nearestID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 230, y: 100, width: 100, height: 80)
            ),
            farID: CanvasNode(
                id: farID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 600, y: 100, width: 100, height: 80)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[focusedID] == nil)
    #expect(result.newState.focusedNodeID == nearestID)
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode skips upper sibling when sibling is also deleted")
func test_apply_deleteFocusedNode_skipsDeletedUpperSibling() async throws {
    let parentID = CanvasNodeID(rawValue: "parent")
    let focusedID = CanvasNodeID(rawValue: "focused")
    let upperSiblingID = CanvasNodeID(rawValue: "upper-sibling")

    let graph = CanvasGraph(
        nodesByID: [
            parentID: CanvasNode(
                id: parentID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 240, width: 100, height: 80)
            ),
            upperSiblingID: CanvasNode(
                id: upperSiblingID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 120, width: 100, height: 80)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-parent-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-focused"),
                fromNodeID: parentID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-parent-upper"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-parent-upper"),
                fromNodeID: parentID,
                toNodeID: upperSiblingID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "edge-focused-upper"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-focused-upper"),
                fromNodeID: focusedID,
                toNodeID: upperSiblingID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[focusedID] == nil)
    #expect(result.newState.nodesByID[upperSiblingID] == nil)
    #expect(result.newState.focusedNodeID == parentID)
}

@Test("ApplyCanvasCommandsUseCase: deleteFocusedNode chooses deterministic parent in multi-parent graph")
func test_apply_deleteFocusedNode_choosesDeterministicParent_whenMultiParent() async throws {
    let parentAID = CanvasNodeID(rawValue: "parent-a")
    let parentBID = CanvasNodeID(rawValue: "parent-b")
    let focusedID = CanvasNodeID(rawValue: "focused")

    let graph = CanvasGraph(
        nodesByID: [
            parentAID: CanvasNode(
                id: parentAID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 80)
            ),
            parentBID: CanvasNode(
                id: parentBID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 200, y: 0, width: 100, height: 80)
            ),
            focusedID: CanvasNode(
                id: focusedID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 100, y: 200, width: 100, height: 80)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "z-parent-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "z-parent-focused"),
                fromNodeID: parentBID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
            CanvasEdgeID(rawValue: "a-parent-focused"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "a-parent-focused"),
                fromNodeID: parentAID,
                toNodeID: focusedID,
                relationType: .parentChild
            ),
        ],
        focusedNodeID: focusedID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(commands: [.deleteFocusedNode])

    #expect(result.newState.nodesByID[focusedID] == nil)
    #expect(result.newState.focusedNodeID == parentAID)
}
