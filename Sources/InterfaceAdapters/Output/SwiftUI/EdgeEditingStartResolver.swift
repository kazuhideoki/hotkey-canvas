// Background: Edge label editing starts from canvas-level key events before a text field is focused.
// Responsibility: Resolve whether a key event should start edge label editing and with which initial cursor placement.
import AppKit
import Domain

/// Resolved context used to start inline editing for the focused edge label.
struct EdgeEditingStartContext {
    let edgeID: CanvasEdgeID
    let label: String
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
    let initialTypingEvent: NSEvent?
}

/// Resolves key events into an inline editing start context for edge labels.
struct EdgeEditingStartResolver {
    func resolve(
        from event: NSEvent,
        focusedEdgeID: CanvasEdgeID?,
        edgesByID: [CanvasEdgeID: CanvasEdge]
    ) -> EdgeEditingStartContext? {
        guard let focusedEdgeID, let focusedEdge = edgesByID[focusedEdgeID] else {
            return nil
        }

        if let placement = controlCursorPlacementForInputStart(from: event) {
            return EdgeEditingStartContext(
                edgeID: focusedEdgeID,
                label: focusedEdge.label ?? "",
                initialCursorPlacement: placement,
                initialTypingEvent: nil
            )
        }

        guard isTypingCharacterEvent(event) else {
            return nil
        }

        return EdgeEditingStartContext(
            edgeID: focusedEdgeID,
            label: "",
            initialCursorPlacement: .end,
            initialTypingEvent: event
        )
    }
}

extension EdgeEditingStartResolver {
    private static let aKeyLowercase = "a"
    private static let eKeyLowercase = "e"

    private func isTypingCharacterEvent(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .function]
        guard flags.isDisjoint(with: disallowed) else {
            return false
        }

        guard let characters = event.characters, !characters.isEmpty else {
            return false
        }
        if characters.rangeOfCharacter(from: .controlCharacters) != nil {
            return false
        }
        return true
    }

    private func controlCursorPlacementForInputStart(
        from event: NSEvent
    ) -> NodeTextEditorInitialCursorPlacement? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .option, .shift, .function]
        guard flags.contains(.control), flags.isDisjoint(with: disallowed) else {
            return nil
        }

        guard let key = event.charactersIgnoringModifiers?.lowercased() else {
            return nil
        }

        switch key {
        case Self.aKeyLowercase:
            return .start
        case Self.eKeyLowercase:
            return .end
        default:
            return nil
        }
    }
}
