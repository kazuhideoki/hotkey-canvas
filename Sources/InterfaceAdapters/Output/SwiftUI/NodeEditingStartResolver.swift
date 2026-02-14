// Background: Canvas editing starts from key events before NSTextView becomes first responder.
// Responsibility: Resolve whether a key event should start node text editing and with which initial cursor placement.
import AppKit
import Domain

/// Resolved context used to start inline editing for the focused node.
struct NodeEditingStartContext: Equatable {
    let nodeID: CanvasNodeID
    let text: String
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
}

/// Resolves key events into an inline editing start context.
struct NodeEditingStartResolver {
    func resolve(
        from event: NSEvent,
        focusedNodeID: CanvasNodeID?,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> NodeEditingStartContext? {
        guard let focusedNodeID, let focusedNode = nodesByID[focusedNodeID] else {
            return nil
        }

        if let placement = controlCursorPlacementForInputStart(from: event) {
            return NodeEditingStartContext(
                nodeID: focusedNodeID,
                text: focusedNode.text ?? "",
                initialCursorPlacement: placement
            )
        }

        guard let typedCharacters = typedCharactersForInputStart(from: event) else {
            return nil
        }

        return NodeEditingStartContext(
            nodeID: focusedNodeID,
            text: typedCharacters,
            initialCursorPlacement: .end
        )
    }
}

extension NodeEditingStartResolver {
    private static let aKeyLowercase = "a"
    private static let eKeyLowercase = "e"

    private func typedCharactersForInputStart(from event: NSEvent) -> String? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .function]
        guard flags.isDisjoint(with: disallowed) else {
            return nil
        }

        guard let characters = event.characters, !characters.isEmpty else {
            return nil
        }
        if characters.rangeOfCharacter(from: .controlCharacters) != nil {
            return nil
        }
        return characters
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
