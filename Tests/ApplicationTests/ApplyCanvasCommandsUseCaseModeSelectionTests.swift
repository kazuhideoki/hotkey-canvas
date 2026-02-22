import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: mode-selected add-node is undoable in one step")
func test_addNodeFromModeSelection_isUndoableInOneStep() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let applied = try await sut.addNodeFromModeSelection(mode: .diagram)
    #expect(applied.newState.nodesByID.count == 1)
    #expect(applied.canUndo)
    let focusedNodeID = try #require(applied.newState.focusedNodeID)
    let addedNode = try #require(applied.newState.nodesByID[focusedNodeID])
    #expect(addedNode.bounds.width == 220)
    #expect(addedNode.bounds.height == 220)

    let undone = await sut.undo()
    #expect(undone.newState.nodesByID.isEmpty)
    #expect(!undone.canUndo)
    #expect(undone.canRedo)
}
