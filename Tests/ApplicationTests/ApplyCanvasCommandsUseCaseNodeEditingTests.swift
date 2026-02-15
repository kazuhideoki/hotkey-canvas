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
    let twentyLineHeightInput = 420.0
    let fortyLineHeightInput = 760.0

    let twentyLineResult = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: twentyLines, nodeHeight: twentyLineHeightInput)]
    )
    let twentyLineHeight = try #require(twentyLineResult.newState.nodesByID[nodeID]?.bounds.height)
    #expect(twentyLineHeight == twentyLineHeightInput)

    let fortyLineResult = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: fortyLines, nodeHeight: fortyLineHeightInput)]
    )
    let fortyLineHeight = try #require(fortyLineResult.newState.nodesByID[nodeID]?.bounds.height)
    #expect(fortyLineHeight == fortyLineHeightInput)
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
    let expandedHeightInput = 760.0
    let shrunkHeightInput = 120.0

    let expanded = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: fortyLines, nodeHeight: expandedHeightInput)]
    )
    let expandedHeight = try #require(expanded.newState.nodesByID[nodeID]?.bounds.height)
    #expect(expandedHeight == expandedHeightInput)

    let shrunk = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "line", nodeHeight: shrunkHeightInput)]
    )
    let shrunkHeight = try #require(shrunk.newState.nodesByID[nodeID]?.bounds.height)
    #expect(shrunkHeight == shrunkHeightInput)
    #expect(shrunkHeight < expandedHeight)
}
