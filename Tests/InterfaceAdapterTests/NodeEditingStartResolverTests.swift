import AppKit
import Domain
import Testing

@testable import InterfaceAdapters

@Test("NodeEditingStartResolver: character key starts editing with typed text")
func test_resolve_characterKey_returnsTypedTextContext() throws {
    let sut = NodeEditingStartResolver()
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let nodesByID = [
        focusedNodeID: CanvasNode(
            id: focusedNodeID,
            kind: .text,
            text: "existing",
            bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 40)
        )
    ]
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "x",
            charactersIgnoringModifiers: "x",
            isARepeat: false,
            keyCode: 7
        )
    )

    let context = sut.resolve(from: event, focusedNodeID: focusedNodeID, nodesByID: nodesByID)

    #expect(context?.nodeID == focusedNodeID)
    #expect(context?.text == "x")
    #expect(context?.initialCursorPlacement == .end)
}

@Test("NodeEditingStartResolver: Ctrl+E starts editing at end with existing text")
func test_resolve_ctrlE_returnsExistingTextWithEndCursor() throws {
    let sut = NodeEditingStartResolver()
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let nodesByID = [
        focusedNodeID: CanvasNode(
            id: focusedNodeID,
            kind: .text,
            text: "existing",
            bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 40)
        )
    ]
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{05}",
            charactersIgnoringModifiers: "e",
            isARepeat: false,
            keyCode: 14
        )
    )

    let context = sut.resolve(from: event, focusedNodeID: focusedNodeID, nodesByID: nodesByID)

    #expect(context?.nodeID == focusedNodeID)
    #expect(context?.text == "existing")
    #expect(context?.initialCursorPlacement == .end)
}

@Test("NodeEditingStartResolver: Ctrl+A starts editing at start with existing text")
func test_resolve_ctrlA_returnsExistingTextWithStartCursor() throws {
    let sut = NodeEditingStartResolver()
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let nodesByID = [
        focusedNodeID: CanvasNode(
            id: focusedNodeID,
            kind: .text,
            text: "existing",
            bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 40)
        )
    ]
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{01}",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )
    )

    let context = sut.resolve(from: event, focusedNodeID: focusedNodeID, nodesByID: nodesByID)

    #expect(context?.nodeID == focusedNodeID)
    #expect(context?.text == "existing")
    #expect(context?.initialCursorPlacement == .start)
}

@Test("NodeEditingStartResolver: Ctrl+non target key does not start editing")
func test_resolve_ctrlNonTarget_returnsNil() throws {
    let sut = NodeEditingStartResolver()
    let focusedNodeID = CanvasNodeID(rawValue: "focused")
    let nodesByID = [
        focusedNodeID: CanvasNode(
            id: focusedNodeID,
            kind: .text,
            text: "existing",
            bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 40)
        )
    ]
    let event = try #require(
        NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "\u{06}",
            charactersIgnoringModifiers: "f",
            isARepeat: false,
            keyCode: 3
        )
    )

    let context = sut.resolve(from: event, focusedNodeID: focusedNodeID, nodesByID: nodesByID)

    #expect(context == nil)
}
