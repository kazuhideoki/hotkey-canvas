// Background: Pure unit tests cannot detect regressions across the hotkey translation and view-model update path.
// Responsibility: Verify keyboard-first interaction flows from input translation to displayed canvas state.
import AppKit
import Application
import Domain
import InterfaceAdapters
import Testing

@MainActor
@Test("Interaction flow: add node, edit text, and apply undo/redo through translated hotkeys")
func test_interactionFlow_addEditUndoRedo_throughTranslatedHotkeys() async throws {
    let inputPort = ApplyCanvasCommandsUseCase(initialGraph: .empty)
    let viewModel = CanvasViewModel(inputPort: inputPort)
    let translator = CanvasHotkeyTranslator()

    _ = await viewModel.onAppear()
    let addNodeEvent = try makeKeyEvent(
        keyCode: 36,
        characters: "\r",
        charactersIgnoringModifiers: "\r",
        modifiers: [.shift]
    )
    await applyTranslatedEvent(addNodeEvent, translator: translator, viewModel: viewModel)

    let addedNodeID = try #require(viewModel.focusedNodeID)
    #expect(viewModel.nodes.count == 1)
    #expect(viewModel.pendingEditingNodeID == addedNodeID)

    await viewModel.commitNodeText(nodeID: addedNodeID, text: "hello", nodeHeight: 96)
    let editedNode = try #require(viewModel.nodes.first(where: { $0.id == addedNodeID }))
    #expect(editedNode.text == "hello")

    let undoEvent = try makeKeyEvent(
        keyCode: 6,
        characters: "z",
        charactersIgnoringModifiers: "z",
        modifiers: [.command]
    )
    await applyTranslatedEvent(undoEvent, translator: translator, viewModel: viewModel)

    let nodeAfterUndo = try #require(viewModel.nodes.first(where: { $0.id == addedNodeID }))
    #expect(nodeAfterUndo.text == nil)

    let redoEvent = try makeKeyEvent(
        keyCode: 6,
        characters: "Z",
        charactersIgnoringModifiers: "z",
        modifiers: [.command, .shift]
    )
    await applyTranslatedEvent(redoEvent, translator: translator, viewModel: viewModel)

    let nodeAfterRedo = try #require(viewModel.nodes.first(where: { $0.id == addedNodeID }))
    #expect(nodeAfterRedo.text == "hello")
}

@MainActor
@Test("Interaction flow: move focus and extend selection through arrow-key translation")
func test_interactionFlow_moveFocusAndExtendSelection_throughTranslatedArrowKeys() async throws {
    let topNodeID = CanvasNodeID(rawValue: "top")
    let bottomNodeID = CanvasNodeID(rawValue: "bottom")
    let graph = CanvasGraph(
        nodesByID: [
            topNodeID: CanvasNode(
                id: topNodeID,
                kind: .text,
                text: "top",
                bounds: CanvasBounds(x: 64, y: 64, width: 220, height: 96)
            ),
            bottomNodeID: CanvasNode(
                id: bottomNodeID,
                kind: .text,
                text: "bottom",
                bounds: CanvasBounds(x: 64, y: 240, width: 220, height: 96)
            ),
        ],
        edgesByID: [:],
        focusedNodeID: topNodeID,
        selectedNodeIDs: [topNodeID],
        areasByID: [
            .defaultTree: CanvasArea(id: .defaultTree, nodeIDs: [topNodeID, bottomNodeID], editingMode: .tree)
        ]
    )
    let inputPort = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let viewModel = CanvasViewModel(inputPort: inputPort)
    let translator = CanvasHotkeyTranslator()

    _ = await viewModel.onAppear()
    let downArrowEvent = try makeKeyEvent(
        keyCode: 125,
        characters: "↓",
        charactersIgnoringModifiers: "↓"
    )
    await applyTranslatedEvent(downArrowEvent, translator: translator, viewModel: viewModel)

    #expect(viewModel.focusedNodeID == bottomNodeID)
    #expect(viewModel.selectedNodeIDs == [bottomNodeID])

    let shiftUpArrowEvent = try makeKeyEvent(
        keyCode: 126,
        characters: "↑",
        charactersIgnoringModifiers: "↑",
        modifiers: [.shift]
    )
    await applyTranslatedEvent(shiftUpArrowEvent, translator: translator, viewModel: viewModel)

    #expect(viewModel.focusedNodeID == topNodeID)
    #expect(viewModel.selectedNodeIDs == [topNodeID, bottomNodeID])
}

@MainActor
@Test("Interaction flow: fold toggle hides descendant nodes and edges in published state")
func test_interactionFlow_toggleFold_hidesPublishedDescendants() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: "root",
                bounds: CanvasBounds(x: 64, y: 64, width: 220, height: 96)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: "child",
                bounds: CanvasBounds(x: 320, y: 64, width: 220, height: 96)
            ),
        ],
        edgesByID: [
            CanvasEdgeID(rawValue: "edge-root-child"): CanvasEdge(
                id: CanvasEdgeID(rawValue: "edge-root-child"),
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID,
        selectedNodeIDs: [rootID],
        areasByID: [
            .defaultTree: CanvasArea(id: .defaultTree, nodeIDs: [rootID, childID], editingMode: .tree)
        ]
    )
    let inputPort = ApplyCanvasCommandsUseCase(initialGraph: graph)
    let viewModel = CanvasViewModel(inputPort: inputPort)
    let translator = CanvasHotkeyTranslator()

    _ = await viewModel.onAppear()
    let toggleFoldEvent = try makeKeyEvent(
        keyCode: 47,
        characters: "≥",
        charactersIgnoringModifiers: ".",
        modifiers: [.option]
    )
    await applyTranslatedEvent(toggleFoldEvent, translator: translator, viewModel: viewModel)

    #expect(viewModel.nodes.map(\.id) == [rootID])
    #expect(viewModel.edges.isEmpty)
    #expect(viewModel.collapsedRootNodeIDs == [rootID])

    await applyTranslatedEvent(toggleFoldEvent, translator: translator, viewModel: viewModel)

    #expect(Set(viewModel.nodes.map(\.id)) == [rootID, childID])
    #expect(viewModel.edges.count == 1)
    #expect(viewModel.collapsedRootNodeIDs.isEmpty)
}

/// Builds a key-down event used to drive translator-level integration tests.
private func makeKeyEvent(
    keyCode: UInt16,
    characters: String,
    charactersIgnoringModifiers: String,
    modifiers: NSEvent.ModifierFlags = []
) throws -> NSEvent {
    try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters,
            charactersIgnoringModifiers: charactersIgnoringModifiers,
            isARepeat: false,
            keyCode: keyCode
        )
    )
}

/// Applies one translated input event to the view model, including undo/redo actions.
@MainActor
private func applyTranslatedEvent(
    _ event: NSEvent,
    translator: CanvasHotkeyTranslator,
    viewModel: CanvasViewModel
) async {
    switch translator.historyAction(event) {
    case .undo:
        await viewModel.undo()
        return
    case .redo:
        await viewModel.redo()
        return
    case .none:
        break
    }

    let commands = translator.translate(event)
    guard !commands.isEmpty else {
        return
    }
    await viewModel.apply(commands: commands)
}
