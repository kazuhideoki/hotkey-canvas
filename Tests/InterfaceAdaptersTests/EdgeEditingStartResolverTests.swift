import AppKit
import Domain
import Testing

@testable import InterfaceAdapters

@Test("EdgeEditingStartResolver: character key starts label editing from empty text")
func test_edgeEditingStartResolver_resolve_characterKey_returnsTypedLabelContext() throws {
    let sut = EdgeEditingStartResolver()
    let focusedEdgeID = CanvasEdgeID(rawValue: "focused-edge")
    let fromNodeID = CanvasNodeID(rawValue: "from")
    let toNodeID = CanvasNodeID(rawValue: "to")
    let edgesByID = [
        focusedEdgeID: CanvasEdge(
            id: focusedEdgeID,
            fromNodeID: fromNodeID,
            toNodeID: toNodeID,
            relationType: .normal,
            label: "existing"
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

    let context = sut.resolve(from: event, focusedEdgeID: focusedEdgeID, edgesByID: edgesByID)

    #expect(context?.edgeID == focusedEdgeID)
    #expect(context?.label == "")
    #expect(context?.initialCursorPlacement == .end)
    #expect(context?.initialTypingEvent != nil)
}

@Test("EdgeEditingStartResolver: Ctrl+E starts editing at end with existing label")
func test_edgeEditingStartResolver_resolve_ctrlE_returnsExistingLabelWithEndCursor() throws {
    let sut = EdgeEditingStartResolver()
    let focusedEdgeID = CanvasEdgeID(rawValue: "focused-edge")
    let fromNodeID = CanvasNodeID(rawValue: "from")
    let toNodeID = CanvasNodeID(rawValue: "to")
    let edgesByID = [
        focusedEdgeID: CanvasEdge(
            id: focusedEdgeID,
            fromNodeID: fromNodeID,
            toNodeID: toNodeID,
            relationType: .normal,
            label: "existing"
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

    let context = sut.resolve(from: event, focusedEdgeID: focusedEdgeID, edgesByID: edgesByID)

    #expect(context?.edgeID == focusedEdgeID)
    #expect(context?.label == "existing")
    #expect(context?.initialCursorPlacement == .end)
    #expect(context?.initialTypingEvent == nil)
}

@Test("EdgeEditingStartResolver: Ctrl+A starts editing at start with existing label")
func test_edgeEditingStartResolver_resolve_ctrlA_returnsExistingLabelWithStartCursor() throws {
    let sut = EdgeEditingStartResolver()
    let focusedEdgeID = CanvasEdgeID(rawValue: "focused-edge")
    let fromNodeID = CanvasNodeID(rawValue: "from")
    let toNodeID = CanvasNodeID(rawValue: "to")
    let edgesByID = [
        focusedEdgeID: CanvasEdge(
            id: focusedEdgeID,
            fromNodeID: fromNodeID,
            toNodeID: toNodeID,
            relationType: .normal,
            label: "existing"
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

    let context = sut.resolve(from: event, focusedEdgeID: focusedEdgeID, edgesByID: edgesByID)

    #expect(context?.edgeID == focusedEdgeID)
    #expect(context?.label == "existing")
    #expect(context?.initialCursorPlacement == .start)
    #expect(context?.initialTypingEvent == nil)
}

@Test("EdgeEditingStartResolver: Ctrl+non target key does not start editing")
func test_edgeEditingStartResolver_resolve_ctrlNonTarget_returnsNil() throws {
    let sut = EdgeEditingStartResolver()
    let focusedEdgeID = CanvasEdgeID(rawValue: "focused-edge")
    let fromNodeID = CanvasNodeID(rawValue: "from")
    let toNodeID = CanvasNodeID(rawValue: "to")
    let edgesByID = [
        focusedEdgeID: CanvasEdge(
            id: focusedEdgeID,
            fromNodeID: fromNodeID,
            toNodeID: toNodeID,
            relationType: .normal,
            label: "existing"
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

    let context = sut.resolve(from: event, focusedEdgeID: focusedEdgeID, edgesByID: edgesByID)

    #expect(context == nil)
}
