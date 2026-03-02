// Background: Command palette supports query-history navigation and recency tracking.
// Responsibility: Isolate history transitions and recent-item bookkeeping from main palette actions.
import Domain

extension CanvasView {
    func handleCommandPaletteArrowKey(_ direction: CommandPaletteArrowDirection) {
        let shouldHandleAsHistory = Self.shouldHandleArrowAsQueryHistory(
            direction: direction,
            selectedCommandIndex: selectedCommandPaletteIndex,
            currentQuery: commandPaletteQuery,
            state: CommandPaletteQueryHistoryState(
                queryHistory: commandPaletteQueryHistory,
                activeHistoryIndex: commandPaletteHistoryNavigationIndex,
                draftQuery: commandPaletteHistoryDraftQuery
            )
        )
        guard shouldHandleAsHistory else {
            switch direction {
            case .up:
                movePaletteSelection(offset: -1)
            case .down:
                movePaletteSelection(offset: 1)
            }
            return
        }

        let currentState = CommandPaletteQueryHistoryState(
            queryHistory: commandPaletteQueryHistory,
            activeHistoryIndex: commandPaletteHistoryNavigationIndex,
            draftQuery: commandPaletteHistoryDraftQuery
        )
        let transition = Self.commandPaletteQueryHistoryTransition(
            currentQuery: commandPaletteQuery,
            state: currentState,
            direction: direction
        )
        commandPaletteHistoryNavigationIndex = transition.nextState.activeHistoryIndex
        commandPaletteHistoryDraftQuery = transition.nextState.draftQuery

        if let nextQuery = transition.nextQuery {
            isApplyingCommandPaletteHistoryQuery = true
            commandPaletteQuery = nextQuery
            return
        }

        switch direction {
        case .up:
            movePaletteSelection(offset: -1)
        case .down:
            movePaletteSelection(offset: 1)
        }
    }

    static func shouldHandleArrowAsQueryHistory(
        direction: CommandPaletteArrowDirection,
        selectedCommandIndex: Int,
        currentQuery: String,
        state: CommandPaletteQueryHistoryState
    ) -> Bool {
        switch direction {
        case .up:
            guard selectedCommandIndex == 0 else {
                return false
            }
            if state.activeHistoryIndex >= 0 {
                return true
            }
            return currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .down:
            return state.activeHistoryIndex >= 0
        }
    }

    static func commandPaletteQueryHistoryTransition(
        currentQuery: String,
        state: CommandPaletteQueryHistoryState,
        direction: CommandPaletteArrowDirection
    ) -> (nextQuery: String?, nextState: CommandPaletteQueryHistoryState) {
        switch direction {
        case .up:
            guard !state.queryHistory.isEmpty else {
                return (nil, state)
            }
            if state.activeHistoryIndex >= 0 {
                let nextIndex = min(state.queryHistory.count - 1, state.activeHistoryIndex + 1)
                guard nextIndex != state.activeHistoryIndex else {
                    return (nil, state)
                }
                return (
                    state.queryHistory[nextIndex],
                    CommandPaletteQueryHistoryState(
                        queryHistory: state.queryHistory,
                        activeHistoryIndex: nextIndex,
                        draftQuery: state.draftQuery
                    )
                )
            }
            guard currentQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return (nil, state)
            }
            return (
                state.queryHistory[0],
                CommandPaletteQueryHistoryState(
                    queryHistory: state.queryHistory,
                    activeHistoryIndex: 0,
                    draftQuery: currentQuery
                )
            )
        case .down:
            guard state.activeHistoryIndex >= 0 else {
                return (nil, state)
            }
            if state.activeHistoryIndex > 0 {
                let nextIndex = state.activeHistoryIndex - 1
                return (
                    state.queryHistory[nextIndex],
                    CommandPaletteQueryHistoryState(
                        queryHistory: state.queryHistory,
                        activeHistoryIndex: nextIndex,
                        draftQuery: state.draftQuery
                    )
                )
            }
            return (
                state.draftQuery,
                CommandPaletteQueryHistoryState(
                    queryHistory: state.queryHistory,
                    activeHistoryIndex: -1,
                    draftQuery: state.draftQuery
                )
            )
        }
    }

    func markCommandPaletteItemAsRecentlyUsed(itemID: String) {
        commandPaletteRecentItemIDs.removeAll { $0 == itemID }
        commandPaletteRecentItemIDs.insert(itemID, at: 0)
        if commandPaletteRecentItemIDs.count > Self.commandPaletteRecentHistoryLimit {
            commandPaletteRecentItemIDs = Array(
                commandPaletteRecentItemIDs.prefix(Self.commandPaletteRecentHistoryLimit)
            )
        }
    }

    func markCommandPaletteQueryAsRecentlyUsed(_ rawQuery: String) {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return
        }
        commandPaletteQueryHistory.removeAll { $0 == query }
        commandPaletteQueryHistory.insert(query, at: 0)
        if commandPaletteQueryHistory.count > Self.commandPaletteQueryHistoryLimit {
            commandPaletteQueryHistory = Array(
                commandPaletteQueryHistory.prefix(Self.commandPaletteQueryHistoryLimit)
            )
        }
    }
}
