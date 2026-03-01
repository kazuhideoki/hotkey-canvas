import Application
import Domain
import Testing

// Background: Edge-target operations must cycle arrow direction deterministically.
// Responsibility: Verify cycleFocusedEdgeDirectionality command behavior.
@Test("ApplyCanvasCommandsUseCase: cycleFocusedEdgeDirectionality cycles none->fromTo->toFrom->none")
func test_apply_cycleFocusedEdgeDirectionality_cyclesDirectionality() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let edgeID = CanvasEdgeID(rawValue: "edge-a-b")
    let areaID = CanvasAreaID(rawValue: "area-diagram")
    let focusedEdge = CanvasEdgeFocus(edgeID: edgeID, originNodeID: nodeAID)

    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: makeCycleEdgeDirectionalityTestNode(id: nodeAID, x: 0, y: 0),
            nodeBID: makeCycleEdgeDirectionalityTestNode(id: nodeBID, x: 300, y: 0),
        ],
        edgesByID: [
            edgeID: CanvasEdge(id: edgeID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal)
        ],
        focusedNodeID: nodeAID,
        focusedElement: .edge(focusedEdge),
        selectedEdgeIDs: [edgeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeAID, nodeBID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let first = try await sut.apply(
        commands: [.cycleFocusedEdgeDirectionality(focusedEdge: focusedEdge, selectedEdgeIDs: [edgeID])]
    )
    #expect(first.newState.edgesByID[edgeID]?.directionality == .fromTo)

    let second = try await sut.apply(
        commands: [.cycleFocusedEdgeDirectionality(focusedEdge: focusedEdge, selectedEdgeIDs: [edgeID])]
    )
    #expect(second.newState.edgesByID[edgeID]?.directionality == .toFrom)

    let third = try await sut.apply(
        commands: [.cycleFocusedEdgeDirectionality(focusedEdge: focusedEdge, selectedEdgeIDs: [edgeID])]
    )
    #expect(third.newState.edgesByID[edgeID]?.directionality == CanvasEdgeDirectionality.none)
}

@Test("ApplyCanvasCommandsUseCase: cycleFocusedEdgeDirectionality becomes no-op when focused edge does not exist")
func test_apply_cycleFocusedEdgeDirectionality_noOpWhenFocusedEdgeMissing() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let existingEdgeID = CanvasEdgeID(rawValue: "edge-a-b")
    let missingEdgeID = CanvasEdgeID(rawValue: "edge-missing")
    let areaID = CanvasAreaID(rawValue: "area-diagram")

    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: makeCycleEdgeDirectionalityTestNode(id: nodeAID, x: 0, y: 0),
            nodeBID: makeCycleEdgeDirectionalityTestNode(id: nodeBID, x: 300, y: 0),
        ],
        edgesByID: [
            existingEdgeID: CanvasEdge(
                id: existingEdgeID,
                fromNodeID: nodeAID,
                toNodeID: nodeBID,
                relationType: .normal,
                directionality: .fromTo
            )
        ],
        focusedNodeID: nodeAID,
        focusedElement: .edge(CanvasEdgeFocus(edgeID: existingEdgeID, originNodeID: nodeAID)),
        selectedEdgeIDs: [existingEdgeID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeAID, nodeBID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(
        commands: [
            .cycleFocusedEdgeDirectionality(
                focusedEdge: CanvasEdgeFocus(edgeID: missingEdgeID, originNodeID: nodeAID),
                selectedEdgeIDs: [missingEdgeID]
            )
        ]
    )

    #expect(result.newState.edgesByID[existingEdgeID]?.directionality == .fromTo)
    #expect(result.newState.focusedElement == .edge(CanvasEdgeFocus(edgeID: existingEdgeID, originNodeID: nodeAID)))
}

@Test("ApplyCanvasCommandsUseCase: cycleFocusedEdgeDirectionality keeps command-provided edge multi-selection")
func test_apply_cycleFocusedEdgeDirectionality_keepsProvidedEdgeMultiSelection() async throws {
    let nodeAID = CanvasNodeID(rawValue: "node-a")
    let nodeBID = CanvasNodeID(rawValue: "node-b")
    let nodeCID = CanvasNodeID(rawValue: "node-c")
    let edgeABID = CanvasEdgeID(rawValue: "edge-a-b")
    let edgeACID = CanvasEdgeID(rawValue: "edge-a-c")
    let areaID = CanvasAreaID(rawValue: "area-diagram")
    let focusedEdge = CanvasEdgeFocus(edgeID: edgeABID, originNodeID: nodeAID)

    let graph = CanvasGraph(
        nodesByID: [
            nodeAID: makeCycleEdgeDirectionalityTestNode(id: nodeAID, x: 0, y: 0),
            nodeBID: makeCycleEdgeDirectionalityTestNode(id: nodeBID, x: 300, y: 0),
            nodeCID: makeCycleEdgeDirectionalityTestNode(id: nodeCID, x: 300, y: 200),
        ],
        edgesByID: [
            edgeABID: CanvasEdge(id: edgeABID, fromNodeID: nodeAID, toNodeID: nodeBID, relationType: .normal),
            edgeACID: CanvasEdge(id: edgeACID, fromNodeID: nodeAID, toNodeID: nodeCID, relationType: .normal),
        ],
        focusedNodeID: nodeAID,
        focusedElement: .edge(focusedEdge),
        selectedEdgeIDs: [edgeABID],
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeAID, nodeBID, nodeCID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let result = try await sut.apply(
        commands: [
            .cycleFocusedEdgeDirectionality(
                focusedEdge: focusedEdge,
                selectedEdgeIDs: [edgeABID, edgeACID]
            )
        ]
    )

    #expect(result.newState.selectedEdgeIDs == [edgeABID, edgeACID])
    #expect(result.newState.focusedElement == .edge(focusedEdge))
}

private func makeCycleEdgeDirectionalityTestNode(id: CanvasNodeID, x: Double, y: Double) -> CanvasNode {
    CanvasNode(
        id: id,
        kind: .text,
        text: nil,
        bounds: CanvasBounds(x: x, y: y, width: 220, height: 120)
    )
}
