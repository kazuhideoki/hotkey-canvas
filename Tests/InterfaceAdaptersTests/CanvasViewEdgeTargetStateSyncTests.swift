import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasView edge target sync: adopts edge target from model-focused edge")
func test_edgeTargetStateSyncedWithModel_adoptsEdgeMode() {
    let edgeID = CanvasEdgeID(rawValue: "edge-focused")

    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .node,
        modelFocusedEdgeID: edgeID,
        modelSelectedEdgeIDs: [edgeID]
    )

    #expect(state.targetKind == .edge)
    #expect(state.focusedEdgeID == edgeID)
    #expect(state.selectedEdgeIDs == [edgeID])
}

@Test("CanvasView edge target sync: drops local edge mode when model has no focused edge")
func test_edgeTargetStateSyncedWithModel_dropsEdgeModeWhenModelHasNoEdgeFocus() {
    let staleEdgeID = CanvasEdgeID(rawValue: "edge-stale")

    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .edge,
        modelFocusedEdgeID: nil,
        modelSelectedEdgeIDs: [staleEdgeID]
    )

    #expect(state.targetKind == .node)
    #expect(state.focusedEdgeID == nil)
    #expect(state.selectedEdgeIDs.isEmpty)
}

@Test("CanvasView edge target sync: keeps node mode unchanged when model has no focused edge")
func test_edgeTargetStateSyncedWithModel_keepsNodeModeWhenModelHasNoEdgeFocus() {
    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .node,
        modelFocusedEdgeID: nil,
        modelSelectedEdgeIDs: []
    )

    #expect(state.targetKind == .node)
    #expect(state.focusedEdgeID == nil)
    #expect(state.selectedEdgeIDs.isEmpty)
}

@Test("CanvasView edge target sync: edge deletion command keeps current selected set")
func test_edgeDeletionCommand_keepsCurrentSelectedSet() {
    let focusedNodeID = CanvasNodeID(rawValue: "node-focused")
    let focusedEdgeID = CanvasEdgeID(rawValue: "edge-focused")
    let selectedEdgeID = CanvasEdgeID(rawValue: "edge-selected")

    let command = CanvasView.edgeDeletionCommand(
        focusedNodeID: focusedNodeID,
        focusedEdgeID: focusedEdgeID,
        selectedEdgeIDs: [focusedEdgeID, selectedEdgeID]
    )

    guard case .deleteSelectedOrFocusedEdges(let focusedEdge, let selectedEdgeIDs) = command else {
        Issue.record("Expected deleteSelectedOrFocusedEdges command")
        return
    }
    #expect(focusedEdge.edgeID == focusedEdgeID)
    #expect(focusedEdge.originNodeID == focusedNodeID)
    #expect(selectedEdgeIDs == [focusedEdgeID, selectedEdgeID])
}
