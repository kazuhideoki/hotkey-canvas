import Application
import Domain
import Testing

@Test("ApplyCanvasCommandsUseCase: undo restores previous graph after addNode")
func test_undo_restoresPreviousGraph_afterAddNode() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let applied = try await sut.apply(commands: [.addNode])
    #expect(applied.newState.nodesByID.count == 1)
    #expect(applied.canUndo)
    #expect(!applied.canRedo)

    let undone = await sut.undo()
    #expect(undone.newState == .empty)
    #expect(!undone.canUndo)
    #expect(undone.canRedo)
}

@Test("ApplyCanvasCommandsUseCase: redo reapplies state after undo")
func test_redo_reappliesState_afterUndo() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    _ = await sut.undo()
    let redone = await sut.redo()

    #expect(redone.newState.nodesByID.count == 1)
    #expect(redone.canUndo)
    #expect(!redone.canRedo)
}

@Test("ApplyCanvasCommandsUseCase: new apply clears redo history")
func test_apply_clearsRedoHistory_afterUndo() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    _ = await sut.undo()
    let reapplied = try await sut.apply(commands: [.addNode])
    #expect(!reapplied.canRedo)

    let redoResult = await sut.redo()
    #expect(redoResult.newState == reapplied.newState)
    #expect(!redoResult.canRedo)
}

@Test("ApplyCanvasCommandsUseCase: maxHistoryCount limits undo depth")
func test_undo_respectsMaxHistoryCount() async throws {
    let sut = ApplyCanvasCommandsUseCase(maxHistoryCount: 1)

    _ = try await sut.apply(commands: [.addNode])
    _ = try await sut.apply(commands: [.addNode])
    let firstUndo = await sut.undo()
    #expect(firstUndo.newState.nodesByID.count == 1)
    #expect(!firstUndo.canUndo)

    let secondUndo = await sut.undo()
    #expect(secondUndo.newState.nodesByID.count == 1)
}

@Test("ApplyCanvasCommandsUseCase: undo emits viewport intent when focus changes")
func test_undo_emitsViewportIntent_whenFocusChanges() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    _ = try await sut.apply(commands: [.addNode])
    let undone = await sut.undo()

    #expect(undone.newState.focusedNodeID != nil)
    #expect(undone.viewportIntent == .resetManualPanOffset)
}

@Test("ApplyCanvasCommandsUseCase: redo emits viewport intent when focus changes")
func test_redo_emitsViewportIntent_whenFocusChanges() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    _ = try await sut.apply(commands: [.addNode])
    _ = try await sut.apply(commands: [.addNode])
    _ = await sut.undo()
    let redone = await sut.redo()

    #expect(redone.newState.focusedNodeID != nil)
    #expect(redone.viewportIntent == .resetManualPanOffset)
}
