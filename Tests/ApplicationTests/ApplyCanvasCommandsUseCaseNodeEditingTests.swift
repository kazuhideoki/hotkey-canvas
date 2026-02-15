import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: setNodeText updates target node, normalizes empty to nil, and persists height")
func test_apply_setNodeText_updatesNodeText() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let updated = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after", nodeHeight: 48)]
    )
    #expect(updated.newState.nodesByID[nodeID]?.text == "after")
    #expect(updated.newState.nodesByID[nodeID]?.bounds.height == 48)

    let cleared = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "", nodeHeight: 44)]
    )
    #expect(cleared.newState.nodesByID[nodeID]?.text == nil)
    #expect(cleared.newState.nodesByID[nodeID]?.bounds.height == 44)
}

@Test("ApplyCanvasCommandsUseCase: setNodeText rejects non-finite height values")
func test_apply_setNodeText_nonFiniteHeight_fallsBackToCurrentHeight() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 70)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let nanHeightResult = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after-nan", nodeHeight: .nan)]
    )
    #expect(nanHeightResult.newState.nodesByID[nodeID]?.text == "after-nan")
    #expect(nanHeightResult.newState.nodesByID[nodeID]?.bounds.height == 70)

    let infinityHeightResult = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after-inf", nodeHeight: .infinity)]
    )
    #expect(infinityHeightResult.newState.nodesByID[nodeID]?.text == "after-inf")
    #expect(infinityHeightResult.newState.nodesByID[nodeID]?.bounds.height == 70)
}

@Test("ApplyCanvasCommandsUseCase: setNodeText expands node height as lines increase")
func test_apply_setNodeText_expandsNodeHeightAsLinesIncrease() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let twentyLines = Array(repeating: "line", count: 20).joined(separator: "\n")
    let fortyLines = Array(repeating: "line", count: 40).joined(separator: "\n")

    let twentyLineResult = try await sut.apply(commands: [.setNodeText(nodeID: nodeID, text: twentyLines)])
    let twentyLineHeight = try #require(twentyLineResult.newState.nodesByID[nodeID]?.bounds.height)
    #expect(twentyLineHeight > 120)

    let fortyLineResult = try await sut.apply(commands: [.setNodeText(nodeID: nodeID, text: fortyLines)])
    let fortyLineHeight = try #require(fortyLineResult.newState.nodesByID[nodeID]?.bounds.height)
    #expect(fortyLineHeight > twentyLineHeight)
}

@Test("ApplyCanvasCommandsUseCase: setNodeText shrinks node height when lines decrease")
func test_apply_setNodeText_shrinksNodeHeightWhenLinesDecrease() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let fortyLines = Array(repeating: "line", count: 40).joined(separator: "\n")

    let expanded = try await sut.apply(commands: [.setNodeText(nodeID: nodeID, text: fortyLines)])
    let expandedHeight = try #require(expanded.newState.nodesByID[nodeID]?.bounds.height)
    #expect(expandedHeight > 120)

    let shrunk = try await sut.apply(commands: [.setNodeText(nodeID: nodeID, text: "line")])
    let shrunkHeight = try #require(shrunk.newState.nodesByID[nodeID]?.bounds.height)
    #expect(shrunkHeight == 120)
    #expect(shrunkHeight < expandedHeight)
}
