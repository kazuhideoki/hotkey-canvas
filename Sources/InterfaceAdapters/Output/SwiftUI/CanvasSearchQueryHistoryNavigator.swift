// Background: Inline search needs terminal-like query history navigation while keeping free-form edits.
// Responsibility: Provide deterministic query-history navigation and persistence helpers for the search panel.
import Foundation

enum CanvasSearchQueryHistoryDirection {
    case older
    case newer
}

enum CanvasSearchQueryHistoryNavigator {
    static let historyLimit = 50

    static func navigate(
        query: String,
        history: [String],
        cursor: Int?,
        draft: String,
        direction: CanvasSearchQueryHistoryDirection
    ) -> (query: String, cursor: Int?, draft: String) {
        guard !history.isEmpty else {
            return (query, cursor, draft)
        }

        switch direction {
        case .older:
            let nextCursor: Int
            let nextDraft: String
            if let cursor {
                nextCursor = min(cursor + 1, history.count - 1)
                nextDraft = draft
            } else {
                nextCursor = 0
                nextDraft = query
            }
            return (history[nextCursor], nextCursor, nextDraft)

        case .newer:
            guard let cursor else {
                return (query, cursor, draft)
            }
            let nextCursor = cursor - 1
            guard nextCursor >= 0 else {
                return (draft, nil, draft)
            }
            return (history[nextCursor], nextCursor, draft)
        }
    }

    static func record(query: String, history: [String], limit: Int = historyLimit) -> [String] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty else {
            return history
        }

        var updatedHistory = history
        updatedHistory.removeAll { $0 == normalizedQuery }
        updatedHistory.insert(normalizedQuery, at: 0)
        if updatedHistory.count > limit {
            updatedHistory = Array(updatedHistory.prefix(limit))
        }
        return updatedHistory
    }

    static func userEditedQuery(
        currentQuery: String,
        cursor: Int?
    ) -> (cursor: Int?, draft: String) {
        guard cursor != nil else {
            return (nil, currentQuery)
        }
        return (nil, currentQuery)
    }
}
