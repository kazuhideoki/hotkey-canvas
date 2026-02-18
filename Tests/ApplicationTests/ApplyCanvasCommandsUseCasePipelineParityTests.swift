import Domain
import Testing

@testable import Application

// Background: Phase-2 introduces a coordinator skeleton while keeping legacy mutation behavior unchanged.
// Responsibility: Verify coordinator safe mode remains graph-equivalent to legacy command sequencing.
@Test("ApplyCanvasCommandsUseCase: pipeline safe mode matches legacy sequence result")
func test_pipelineSafeMode_matchesLegacySequenceResult() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let firstChildID = CanvasNodeID(rawValue: "first-child")
    let secondChildID = CanvasNodeID(rawValue: "second-child")
    let baseGraph = makePipelineParityBaseGraph(
        rootID: rootID,
        firstChildID: firstChildID,
        secondChildID: secondChildID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: baseGraph)

    let commands: [CanvasCommand] = [
        .moveNode(.down),
        .setNodeText(nodeID: firstChildID, text: "updated", nodeHeight: 88),
        .moveFocus(.down),
        .deleteFocusedNode,
    ]

    let legacyGraph = try await sut.runLegacyCommandSequence(commands: commands, from: baseGraph)
    let pipelineResult = try await sut.runPipelineCommandSequence(commands: commands, from: baseGraph)

    #expect(pipelineResult.graph == legacyGraph)
    #expect(pipelineResult.viewportIntent == .resetManualPanOffset)
    #expect(!pipelineResult.didAddNode)
}

@Test("ApplyCanvasCommandsUseCase: pipeline safe mode keeps no-op sequence unchanged")
func test_pipelineSafeMode_keepsNoOpSequenceUnchanged() async throws {
    let sut = ApplyCanvasCommandsUseCase(initialGraph: .empty)
    let commands: [CanvasCommand] = [
        .moveFocus(.left),
        .deleteFocusedNode,
        .addSiblingNode(position: .above),
    ]

    let legacyGraph = try await sut.runLegacyCommandSequence(commands: commands, from: .empty)
    let pipelineResult = try await sut.runPipelineCommandSequence(commands: commands, from: .empty)

    #expect(legacyGraph == .empty)
    #expect(pipelineResult.graph == legacyGraph)
    #expect(pipelineResult.viewportIntent == nil)
    #expect(!pipelineResult.didAddNode)
}

private func makePipelineParityBaseGraph(
    rootID: CanvasNodeID,
    firstChildID: CanvasNodeID,
    secondChildID: CanvasNodeID
) -> CanvasGraph {
    let rootNode = CanvasNode(
        id: rootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
    )
    let firstChildNode = CanvasNode(
        id: firstChildID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 320, y: 48, width: 220, height: 120)
    )
    let secondChildNode = CanvasNode(
        id: secondChildID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 320, y: 220, width: 220, height: 120)
    )
    let firstEdge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-first"),
        fromNodeID: rootID,
        toNodeID: firstChildID,
        relationType: .parentChild
    )
    let secondEdge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-second"),
        fromNodeID: rootID,
        toNodeID: secondChildID,
        relationType: .parentChild
    )

    return CanvasGraph(
        nodesByID: [
            rootID: rootNode,
            firstChildID: firstChildNode,
            secondChildID: secondChildNode,
        ],
        edgesByID: [
            firstEdge.id: firstEdge,
            secondEdge.id: secondEdge,
        ],
        focusedNodeID: firstChildID
    )
}
