import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasView add-node mode selection: area-origin commit arms node-target switch")
func test_addNodeModeSelectionTargetTransition_areaCommitArmsNodeTargetSwitch() {
    #expect(
        CanvasView.shouldSwitchToNodeTargetAfterAddNodeModeSelectionCommit(
            currentTargetKind: .area
        )
    )
}

@Test("CanvasView add-node mode selection: node-origin commit does not arm node-target switch")
func test_addNodeModeSelectionTargetTransition_nodeCommitDoesNotArmNodeTargetSwitch() {
    #expect(
        !CanvasView.shouldSwitchToNodeTargetAfterAddNodeModeSelectionCommit(
            currentTargetKind: .node
        )
    )
}

@Test("CanvasView add-node mode selection: successful area-origin add switches to node target and clears flag")
func test_addNodeModeSelectionTargetTransition_successfulAreaAddSwitchesToNodeTarget() {
    let transition = CanvasView.pendingAddNodeEditingTransition(
        currentTargetKind: .area,
        shouldSwitchToNodeTargetAfterCommit: true,
        hasResolvedPendingEditingNode: true
    )

    #expect(
        transition == CanvasView.PendingAddNodeEditingTransitionState(
            targetKind: .node,
            shouldSwitchToNodeTargetAfterCommit: false
        )
    )
}

@Test("CanvasView add-node mode selection: failed area-origin add keeps area target and clears flag")
func test_addNodeModeSelectionTargetTransition_failedAreaAddKeepsAreaTarget() {
    let transition = CanvasView.pendingAddNodeEditingTransition(
        currentTargetKind: .area,
        shouldSwitchToNodeTargetAfterCommit: true,
        hasResolvedPendingEditingNode: false
    )

    #expect(
        transition == CanvasView.PendingAddNodeEditingTransitionState(
            targetKind: .area,
            shouldSwitchToNodeTargetAfterCommit: false
        )
    )
}

@Test("CanvasView add-node mode selection: cancelled popup keeps area target without arming switch")
func test_addNodeModeSelectionTargetTransition_cancelledPopupKeepsAreaTarget() {
    let transition = CanvasView.pendingAddNodeEditingTransition(
        currentTargetKind: .area,
        shouldSwitchToNodeTargetAfterCommit: false,
        hasResolvedPendingEditingNode: false
    )

    #expect(
        transition == CanvasView.PendingAddNodeEditingTransitionState(
            targetKind: .area,
            shouldSwitchToNodeTargetAfterCommit: false
        )
    )
}
