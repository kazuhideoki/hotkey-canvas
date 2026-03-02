// Background: Inline search needs terminal-like query history navigation while keeping free-form edits.
// Responsibility: Provide deterministic query-history navigation and persistence helpers for the search panel.
import Foundation

enum CanvasSearchQueryHistoryDirection {
    case older
    case newer
}

enum CanvasSearchQueryHistoryNavigator {
    static let historyLimit = 50

    struct NavigationState: Equatable {
        let query: String
        let cursor: Int?
        let draft: String
    }

    static func navigate(
        query: String,
        history: [String],
        cursor: Int?,
        draft: String,
        direction: CanvasSearchQueryHistoryDirection
    ) -> NavigationState {
        guard !history.isEmpty else {
            return NavigationState(query: query, cursor: cursor, draft: draft)
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
            return NavigationState(query: history[nextCursor], cursor: nextCursor, draft: nextDraft)

        case .newer:
            guard let cursor else {
                return NavigationState(query: query, cursor: cursor, draft: draft)
            }
            let nextCursor = cursor - 1
            guard nextCursor >= 0 else {
                return NavigationState(query: draft, cursor: nil, draft: draft)
            }
            return NavigationState(query: history[nextCursor], cursor: nextCursor, draft: draft)
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
