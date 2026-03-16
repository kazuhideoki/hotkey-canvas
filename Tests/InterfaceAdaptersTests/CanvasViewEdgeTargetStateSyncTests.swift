import Domain
import Testing

@testable import InterfaceAdapters

@Test("モデル中心のエッジからエッジターゲットを採用")
func test_edgeTargetStateSyncedWithModel_adoptsEdgeMode() {
    let edgeID = CanvasEdgeID(rawValue: "edge-focused")

    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .node,
        modelFocusedEdgeID: edgeID,
        modelFocusedAreaID: nil,
        modelSelectedEdgeIDs: [edgeID]
    )

    #expect(state.targetKind == .edge)
    #expect(state.focusedEdgeID == edgeID)
    #expect(state.selectedEdgeIDs == [edgeID])
}

@Test("モデルにフォーカス中のエッジがない場合、ローカル エッジ モードを削除する")
func test_edgeTargetStateSyncedWithModel_dropsEdgeModeWhenModelHasNoEdgeFocus() {
    let staleEdgeID = CanvasEdgeID(rawValue: "edge-stale")

    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .edge,
        modelFocusedEdgeID: nil,
        modelFocusedAreaID: nil,
        modelSelectedEdgeIDs: [staleEdgeID]
    )

    #expect(state.targetKind == .node)
    #expect(state.focusedEdgeID == nil)
    #expect(state.selectedEdgeIDs.isEmpty)
}

@Test("モデルにフォーカス中のエッジがない場合、ノード モードは変更されない")
func test_edgeTargetStateSyncedWithModel_keepsNodeModeWhenModelHasNoEdgeFocus() {
    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .node,
        modelFocusedEdgeID: nil,
        modelFocusedAreaID: nil,
        modelSelectedEdgeIDs: []
    )

    #expect(state.targetKind == .node)
    #expect(state.focusedEdgeID == nil)
    #expect(state.selectedEdgeIDs.isEmpty)
}

@Test("モデルにフォーカス中のエリアがない場合、古いエリアモードを削除する")
func test_edgeTargetStateSyncedWithModel_dropsAreaModeWhenModelHasNoAreaFocus() {
    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .area,
        modelFocusedEdgeID: nil,
        modelFocusedAreaID: nil,
        modelSelectedEdgeIDs: []
    )

    #expect(state.targetKind == .node)
    #expect(state.focusedEdgeID == nil)
    #expect(state.selectedEdgeIDs.isEmpty)
}

@Test("モデルに重点を置いたエリアが存在する場合、エリアターゲットを採用する")
func test_edgeTargetStateSyncedWithModel_adoptsAreaMode() {
    let areaID = CanvasAreaID(rawValue: "area-1")

    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .node,
        modelFocusedEdgeID: nil,
        modelFocusedAreaID: areaID,
        modelSelectedEdgeIDs: []
    )

    #expect(state.targetKind == .area)
    #expect(state.focusedEdgeID == nil)
    #expect(state.selectedEdgeIDs.isEmpty)
}

@Test("エリアフォーカスは古いエッジモードをオーバーライドする")
func test_edgeTargetStateSyncedWithModel_areaFocusOverridesEdgeMode() {
    let areaID = CanvasAreaID(rawValue: "area-1")
    let staleEdgeID = CanvasEdgeID(rawValue: "edge-stale")

    let state = CanvasView.edgeTargetStateSyncedWithModel(
        currentTargetKind: .edge,
        modelFocusedEdgeID: nil,
        modelFocusedAreaID: areaID,
        modelSelectedEdgeIDs: [staleEdgeID]
    )

    #expect(state.targetKind == .area)
    #expect(state.focusedEdgeID == nil)
    #expect(state.selectedEdgeIDs.isEmpty)
}

@Test("エッジ削除コマンドは現在選択されているセットを保持する")
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

@Test("エッジ方向性コマンドは、フォーカス中のエッジ、原点ノード、および選択を維持する")
func test_edgeDirectionalityCycleCommand_keepsFocusedEdgeOriginNodeAndSelection() {
    let focusedNodeID = CanvasNodeID(rawValue: "node-focused")
    let focusedEdgeID = CanvasEdgeID(rawValue: "edge-focused")
    let selectedEdgeID = CanvasEdgeID(rawValue: "edge-selected")

    let command = CanvasView.edgeDirectionalityCycleCommand(
        focusedNodeID: focusedNodeID,
        focusedEdgeID: focusedEdgeID,
        selectedEdgeIDs: [focusedEdgeID, selectedEdgeID]
    )

    guard case .cycleFocusedEdgeDirectionality(let focusedEdge, let selectedEdgeIDs) = command else {
        Issue.record("Expected cycleFocusedEdgeDirectionality command")
        return
    }
    #expect(focusedEdge.edgeID == focusedEdgeID)
    #expect(focusedEdge.originNodeID == focusedNodeID)
    #expect(selectedEdgeIDs == [focusedEdgeID, selectedEdgeID])
}
