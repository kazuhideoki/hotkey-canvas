import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: setNodeText updates target node and normalizes empty to nil")
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

    let updated = try await sut.apply(commands: [.setNodeText(nodeID: nodeID, text: "after")])
    #expect(updated.newState.nodesByID[nodeID]?.text == "after")

    let cleared = try await sut.apply(commands: [.setNodeText(nodeID: nodeID, text: "")])
    #expect(cleared.newState.nodesByID[nodeID]?.text == nil)
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
