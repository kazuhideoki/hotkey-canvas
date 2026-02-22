import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasView composite move: enabled when focused node is diagram node")
func test_shouldEnableCompositeMove_diagramFocused_returnsTrue() {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let diagramNodeIDs: Set<CanvasNodeID> = [focusedNodeID]

    let result = CanvasView.shouldEnableCompositeMove(
        focusedNodeID: focusedNodeID,
        diagramNodeIDs: diagramNodeIDs
    )

    #expect(result)
}

@Test("CanvasView composite move: disabled when focused node is not in diagram nodes")
func test_shouldEnableCompositeMove_treeFocused_returnsFalse() {
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let diagramNodeIDs: Set<CanvasNodeID> = [CanvasNodeID(rawValue: "diagram")]

    let result = CanvasView.shouldEnableCompositeMove(
        focusedNodeID: focusedNodeID,
        diagramNodeIDs: diagramNodeIDs
    )

    #expect(!result)
}

@Test("CanvasView composite move: disabled when no focused node")
func test_shouldEnableCompositeMove_withoutFocusedNode_returnsFalse() {
    let diagramNodeIDs: Set<CanvasNodeID> = [CanvasNodeID(rawValue: "diagram")]

    let result = CanvasView.shouldEnableCompositeMove(
        focusedNodeID: nil,
        diagramNodeIDs: diagramNodeIDs
    )

    #expect(!result)
}

@Test("CanvasView composite move: reset state when focused node changes")
func test_shouldResetCompositeMoveState_focusChanged_returnsTrue() {
    let previousFocusedNodeID = CanvasNodeID(rawValue: "before")
    let currentFocusedNodeID = CanvasNodeID(rawValue: "after")

    let result = CanvasView.shouldResetCompositeMoveState(
        previousFocusedNodeID: previousFocusedNodeID,
        currentFocusedNodeID: currentFocusedNodeID
    )

    #expect(result)
}

@Test("CanvasView composite move: keep state when focused node is unchanged")
func test_shouldResetCompositeMoveState_focusUnchanged_returnsFalse() {
    let focusedNodeID = CanvasNodeID(rawValue: "same")

    let result = CanvasView.shouldResetCompositeMoveState(
        previousFocusedNodeID: focusedNodeID,
        currentFocusedNodeID: focusedNodeID
    )

    #expect(!result)
}
