import Domain
import Testing

@testable import Application

// Background: Phase-3 routes tree/area recomputation through the coordinator pipeline.
// Responsibility: Verify pipeline execution still produces stable graph outputs.
@Test("ApplyCanvasCommandsUseCase: pipeline mode produces deterministic result for mixed command sequence")
func test_pipelineMode_matchesExpectedResultForMixedCommandSequence() async throws {
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

    let pipelineResult = try await sut.runPipelineCommandSequence(commands: commands, from: baseGraph)
    let replayResult = try await sut.runPipelineCommandSequence(commands: commands, from: baseGraph)

    #expect(pipelineResult.graph == replayResult.graph)
    #expect(pipelineResult.graph.focusedNodeID == secondChildID)
    #expect(pipelineResult.graph.nodesByID.count == 2)
    #expect(pipelineResult.viewportIntent == nil)
    #expect(!pipelineResult.didAddNode)
}

@Test("ApplyCanvasCommandsUseCase: pipeline mode keeps no-op sequence unchanged")
func test_pipelineMode_keepsNoOpSequenceUnchanged() async throws {
    let sut = ApplyCanvasCommandsUseCase(initialGraph: .empty)
    let commands: [CanvasCommand] = [
        .moveFocus(.left),
        .deleteFocusedNode,
        .addSiblingNode(position: .above),
    ]

    let pipelineResult = try await sut.runPipelineCommandSequence(commands: commands, from: .empty)

    #expect(pipelineResult.graph == .empty)
    #expect(pipelineResult.viewportIntent == nil)
    #expect(!pipelineResult.didAddNode)
}

@Test("ApplyCanvasCommandsUseCase: batched pipeline command sequence matches staged step-by-step execution")
func test_pipelineMode_batchedSequence_matchesStepByStepExecution() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let firstChildID = CanvasNodeID(rawValue: "first-child")
    let secondChildID = CanvasNodeID(rawValue: "second-child")
    let baseGraph = makePipelineParityBaseGraph(
        rootID: rootID,
        firstChildID: firstChildID,
        secondChildID: secondChildID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: baseGraph)

    let firstCommand = CanvasCommand.setNodeText(
        nodeID: firstChildID,
        text: "expanded",
        nodeHeight: 220
    )
    let secondCommand = CanvasCommand.moveFocus(.down)

    let batchedResult = try await sut.runPipelineCommandSequence(
        commands: [firstCommand, secondCommand],
        from: baseGraph
    )
    let firstStep = try await sut.runPipelineCommandSequence(
        commands: [firstCommand],
        from: baseGraph
    )
    let secondStep = try await sut.runPipelineCommandSequence(
        commands: [secondCommand],
        from: firstStep.graph
    )

    #expect(batchedResult.graph == secondStep.graph)
    #expect(batchedResult.viewportIntent == secondStep.viewportIntent)
}

@Test("ApplyCanvasCommandsUseCase: didAddNode is false when added node does not remain in final graph")
func test_pipelineMode_didAddNode_isFalseForTransientAdd() async throws {
    let sut = ApplyCanvasCommandsUseCase(initialGraph: .empty)

    let result = try await sut.runPipelineCommandSequence(
        commands: [.addNode, .deleteFocusedNode],
        from: .empty
    )

    #expect(result.graph == .empty)
    #expect(!result.didAddNode)
}

@Test("ApplyCanvasCommandsUseCase: apply does not return viewport intent when focus changes")
func test_apply_doesNotReturnViewportIntent_whenFocusChanges() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let rootNode = CanvasNode(
        id: rootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
    )
    let childNode = CanvasNode(
        id: childID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 48, y: 240, width: 220, height: 120)
    )
    let graph = CanvasGraph(
        nodesByID: [rootID: rootNode, childID: childNode],
        edgesByID: [:],
        focusedNodeID: rootID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let applyResult = try await sut.apply(commands: [.moveFocus(.down)])

    #expect(applyResult.newState.focusedNodeID == childID)
    #expect(applyResult.viewportIntent == nil)
}

@Test("CanvasCommandPipelineCoordinator: tree/area stages are idempotent")
func test_pipelineCoordinator_treeAreaStages_areIdempotent() {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")

    let rootNode = CanvasNode(
        id: rootID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 48, y: 48, width: 220, height: 120)
    )
    let childNode = CanvasNode(
        id: childID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 320, y: 220, width: 220, height: 120)
    )
    let edge = CanvasEdge(
        id: CanvasEdgeID(rawValue: "edge-root-child"),
        fromNodeID: rootID,
        toNodeID: childID,
        relationType: .parentChild
    )
    let baseGraph = CanvasGraph(
        nodesByID: [rootID: rootNode, childID: childNode],
        edgesByID: [edge.id: edge],
        focusedNodeID: childID
    )
    let coordinator = CanvasCommandPipelineCoordinator()

    let firstPass = coordinator.run(
        on: baseGraph,
        mutationResults: [
            CanvasMutationResult(
                graphBeforeMutation: baseGraph,
                graphAfterMutation: baseGraph,
                effects: CanvasMutationEffects(
                    didMutateGraph: true,
                    needsTreeLayout: true,
                    needsAreaLayout: true,
                    needsFocusNormalization: false
                ),
                areaLayoutSeedNodeID: childID
            )
        ]
    )
    let secondPass = coordinator.run(
        on: firstPass.graph,
        mutationResults: [
            CanvasMutationResult(
                graphBeforeMutation: firstPass.graph,
                graphAfterMutation: firstPass.graph,
                effects: CanvasMutationEffects(
                    didMutateGraph: true,
                    needsTreeLayout: true,
                    needsAreaLayout: true,
                    needsFocusNormalization: false
                ),
                areaLayoutSeedNodeID: childID
            )
        ]
    )

    #expect(secondPass.graph == firstPass.graph)
}

@Test("CanvasCommandPipelineCoordinator: focus normalization resolves invalid focused node to deterministic fallback")
func test_pipelineCoordinator_focusNormalization_resolvesInvalidFocus() {
    let upperID = CanvasNodeID(rawValue: "upper")
    let lowerID = CanvasNodeID(rawValue: "lower")
    let invalidFocusedNodeID = CanvasNodeID(rawValue: "missing")
    let upperNode = CanvasNode(
        id: upperID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 80, y: 40, width: 220, height: 80)
    )
    let lowerNode = CanvasNode(
        id: lowerID,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: 80, y: 180, width: 220, height: 80)
    )
    let graphWithInvalidFocus = CanvasGraph(
        nodesByID: [upperID: upperNode, lowerID: lowerNode],
        edgesByID: [:],
        focusedNodeID: invalidFocusedNodeID
    )
    let coordinator = CanvasCommandPipelineCoordinator()

    let result = coordinator.run(
        on: graphWithInvalidFocus,
        mutationResults: [
            CanvasMutationResult(
                graphBeforeMutation: graphWithInvalidFocus,
                graphAfterMutation: graphWithInvalidFocus,
                effects: CanvasMutationEffects(
                    didMutateGraph: true,
                    needsTreeLayout: false,
                    needsAreaLayout: false,
                    needsFocusNormalization: true
                )
            )
        ]
    )

    #expect(result.graph.focusedNodeID == upperID)
    #expect(result.viewportIntent == nil)
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
