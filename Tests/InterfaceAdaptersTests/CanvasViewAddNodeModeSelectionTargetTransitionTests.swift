import Domain
import Testing

@testable import InterfaceAdapters

@Test("エリア起点で確定すると、ノードターゲットへの切り替えを準備する")
func test_addNodeModeSelectionTargetTransition_areaCommitArmsNodeTargetSwitch() {
    #expect(
        CanvasView.shouldSwitchToNodeTargetAfterAddNodeModeSelectionCommit(
            currentTargetKind: .area
        )
    )
}

@Test("ノード起点のコミットはノードとターゲットの切り替えを準備しない")
func test_addNodeModeSelectionTargetTransition_nodeCommitDoesNotArmNodeTargetSwitch() {
    #expect(
        !CanvasView.shouldSwitchToNodeTargetAfterAddNodeModeSelectionCommit(
            currentTargetKind: .node
        )
    )
}

@Test("エリア起点の追加が成功すると、ノードターゲットへ切り替わり、フラグがクリアされる")
func test_addNodeModeSelectionTargetTransition_successfulAreaAddSwitchesToNodeTarget() {
    let transition = CanvasView.pendingAddNodeEditingTransition(
        currentTargetKind: .area,
        shouldSwitchToNodeTargetAfterCommit: true,
        hasResolvedPendingEditingNode: true
    )

    #expect(
        transition
            == CanvasView.PendingAddNodeEditingTransitionState(
                targetKind: .node,
                shouldSwitchToNodeTargetAfterCommit: false
            )
    )
}

@Test("失敗したエリア原点の追加はエリアターゲットを保持し、フラグをクリアする")
func test_addNodeModeSelectionTargetTransition_failedAreaAddKeepsAreaTarget() {
    let transition = CanvasView.pendingAddNodeEditingTransition(
        currentTargetKind: .area,
        shouldSwitchToNodeTargetAfterCommit: true,
        hasResolvedPendingEditingNode: false
    )

    #expect(
        transition
            == CanvasView.PendingAddNodeEditingTransitionState(
                targetKind: .area,
                shouldSwitchToNodeTargetAfterCommit: false
            )
    )
}

@Test("ポップアップをキャンセルすると、スイッチを解除せずにエリアターゲットを維持する")
func test_addNodeModeSelectionTargetTransition_cancelledPopupKeepsAreaTarget() {
    let transition = CanvasView.pendingAddNodeEditingTransition(
        currentTargetKind: .area,
        shouldSwitchToNodeTargetAfterCommit: false,
        hasResolvedPendingEditingNode: false
    )

    #expect(
        transition
            == CanvasView.PendingAddNodeEditingTransitionState(
                targetKind: .area,
                shouldSwitchToNodeTargetAfterCommit: false
            )
    )
}
