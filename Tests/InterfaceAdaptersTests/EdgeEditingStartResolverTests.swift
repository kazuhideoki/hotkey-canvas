import AppKit
import Domain
import Testing

@testable import InterfaceAdapters

@Test("文字キーは空のテキストからラベル編集を開始する")
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

@Test("Ctrl+E は既存のラベルの最後に編集を開始する")
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

@Test("Ctrl+A は既存のラベルで開始時に編集を開始する")
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

@Test("Ctrl+ターゲット以外のキーを押しても編集が開始されない")
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
