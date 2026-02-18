// Background: Command palette query input is handled from raw key events, not native TextField editing.
// Responsibility: Provide deterministic query/cursor editing primitives used by command palette key handling.
import Foundation

/// Pure editing helpers for command palette query and caret position.
enum CommandPaletteQueryEditing {
    /// Clamps cursor index into query bounds.
    /// - Parameters:
    ///   - cursorIndex: Candidate caret index.
    ///   - query: Query text used as bounds.
    /// - Returns: Safe cursor index within `0...query.count`.
    static func clampedCursorIndex(_ cursorIndex: Int, in query: String) -> Int {
        min(max(0, cursorIndex), query.count)
    }

    /// Moves cursor by offset while staying in bounds.
    /// - Parameters:
    ///   - cursorIndex: Current cursor position.
    ///   - offset: Signed movement amount.
    ///   - query: Query text used as bounds.
    /// - Returns: Updated bounded cursor index.
    static func movedCursorIndex(
        from cursorIndex: Int,
        offset: Int,
        in query: String
    ) -> Int {
        clampedCursorIndex(cursorIndex + offset, in: query)
    }

    /// Inserts one character at cursor position.
    /// - Parameters:
    ///   - character: Character to insert.
    ///   - query: Existing query text.
    ///   - cursorIndex: Current cursor position.
    /// - Returns: Updated query and cursor index.
    static func inserting(
        _ character: Character,
        into query: String,
        cursorIndex: Int
    ) -> (query: String, cursorIndex: Int) {
        var characters = Array(query)
        let insertionIndex = clampedCursorIndex(cursorIndex, in: query)
        characters.insert(character, at: insertionIndex)
        return (String(characters), insertionIndex + 1)
    }

    /// Deletes one character before cursor.
    /// - Parameters:
    ///   - query: Existing query text.
    ///   - cursorIndex: Current cursor position.
    /// - Returns: Updated query and cursor index.
    static func deletingBackward(
        in query: String,
        cursorIndex: Int
    ) -> (query: String, cursorIndex: Int) {
        let boundedCursorIndex = clampedCursorIndex(cursorIndex, in: query)
        guard boundedCursorIndex > 0 else {
            return (query, boundedCursorIndex)
        }
        var characters = Array(query)
        let deletionIndex = boundedCursorIndex - 1
        characters.remove(at: deletionIndex)
        return (String(characters), deletionIndex)
    }

    /// Deletes one character at cursor position.
    /// - Parameters:
    ///   - query: Existing query text.
    ///   - cursorIndex: Current cursor position.
    /// - Returns: Updated query and cursor index.
    static func deletingForward(
        in query: String,
        cursorIndex: Int
    ) -> (query: String, cursorIndex: Int) {
        let boundedCursorIndex = clampedCursorIndex(cursorIndex, in: query)
        var characters = Array(query)
        guard characters.indices.contains(boundedCursorIndex) else {
            return (query, boundedCursorIndex)
        }
        characters.remove(at: boundedCursorIndex)
        return (String(characters), boundedCursorIndex)
    }

    /// Splits query text around cursor.
    /// - Parameters:
    ///   - query: Query text.
    ///   - cursorIndex: Cursor position.
    /// - Returns: Prefix before cursor and suffix after cursor.
    static func split(
        _ query: String,
        cursorIndex: Int
    ) -> (prefix: String, suffix: String) {
        let characters = Array(query)
        let boundedCursorIndex = clampedCursorIndex(cursorIndex, in: query)
        return (
            prefix: String(characters.prefix(boundedCursorIndex)),
            suffix: String(characters.suffix(characters.count - boundedCursorIndex))
        )
    }
}
