// Background: Command palette interactions need isolated key handling and filtering helpers.
// Responsibility: Provide command palette behavior for keyboard handling and action dispatch.
import Application
import Domain
import Foundation

extension CanvasView {
    static let commandPaletteRecentPinnedCount = 5
    static let commandPaletteRecentHistoryLimit = 50
    static let commandPaletteQueryHistoryLimit = 50

    enum CommandPaletteArrowDirection {
        case up
        case down
    }

    struct CommandPaletteQueryHistoryState: Equatable {
        let queryHistory: [String]
        let activeHistoryIndex: Int
        let draftQuery: String
    }

    enum CommandPaletteAction: Equatable {
        case shortcut(CanvasShortcutAction)
        case deleteSelectedOrFocusedEdges(CanvasCommand)
        case cycleFocusedEdgeDirectionality(CanvasCommand)
        case insertImageFromFinder
    }

    struct CommandPaletteItem: Identifiable, Equatable {
        let id: String
        let title: String
        let shortcutLabel: String
        let hasShortcutBinding: Bool
        let searchText: String
        let action: CommandPaletteAction

        init(
            id: String,
            title: String,
            shortcutLabel: String,
            hasShortcutBinding: Bool = true,
            searchText: String,
            action: CommandPaletteAction
        ) {
            self.id = id
            self.title = title
            self.shortcutLabel = shortcutLabel
            self.hasShortcutBinding = hasShortcutBinding
            self.searchText = searchText
            self.action = action
        }
    }

    func openCommandPalette() {
        isSearchPresented = false
        searchFocusedMatch = nil
        isCommandPalettePresented = true
        selectedCommandPaletteIndex = 0
        commandPaletteQuery = ""
        commandPaletteHistoryNavigationIndex = -1
        commandPaletteHistoryDraftQuery = ""
        isApplyingCommandPaletteHistoryQuery = false
    }

    func closeCommandPalette() {
        isCommandPalettePresented = false
    }

    func movePaletteSelection(offset: Int) {
        let items = filteredCommandPaletteItems()
        guard !items.isEmpty else {
            return
        }
        let maxIndex = max(0, items.count - 1)
        selectedCommandPaletteIndex = min(maxIndex, max(0, selectedCommandPaletteIndex + offset))
    }

    func filteredCommandPaletteItems() -> [CommandPaletteItem] {
        let orderedItems = defaultCommandPaletteItems()
            .sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
        let prioritizedItems = Self.commandPaletteItemsPrioritizingRecent(
            orderedItems,
            recentItemIDs: commandPaletteRecentItemIDs,
            maxPinnedCount: Self.commandPaletteRecentPinnedCount
        )

        guard !commandPaletteQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return prioritizedItems
        }

        return prioritizedItems.filter { item in
            matchesCommandPaletteQuery(item.searchText, commandPaletteQuery)
        }
    }

    private func defaultCommandPaletteItems() -> [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []
        let context = commandPaletteContext()
        let keymapContext = keymapExecutionContextForCommandPalette()
        for definition in CanvasShortcutCatalogService.commandPaletteDefinitions(
            context: context,
            executionContext: keymapContext
        ) {
            if operationTargetKind == .edge, definition.id.rawValue == "deleteSelectedOrFocusedNodes" {
                continue
            }
            let searchText = Self.commandPaletteSearchText(
                title: definition.title,
                shortcutLabel: definition.shortcutLabel,
                searchTokens: definition.searchTokens
            )
            items.append(
                CommandPaletteItem(
                    id: definition.id.rawValue,
                    title: definition.title,
                    shortcutLabel: definition.shortcutLabel,
                    searchText: searchText,
                    action: .shortcut(definition.action)
                )
            )
        }
        if operationTargetKind == .node,
            let markdownToggleItem = focusedNodeMarkdownToggleCommandPaletteItem()
        {
            items.append(markdownToggleItem)
        }
        if let edgeDeletionItem = edgeDeletionCommandPaletteItem() {
            items.append(edgeDeletionItem)
        }
        if let edgeDirectionalityItem = edgeDirectionalityCommandPaletteItem() {
            items.append(edgeDirectionalityItem)
        }
        if operationTargetKind == .node, viewModel.focusedNodeID != nil {
            items.append(
                CommandPaletteItem(
                    id: "insertImageFromFinder",
                    title: "Image: Insert From Finder",
                    shortcutLabel: "Finder",
                    hasShortcutBinding: false,
                    searchText: Self.commandPaletteSearchText(
                        title: "Image: Insert From Finder",
                        shortcutLabel: "Finder",
                        searchTokens: ["insert", "image", "finder", "photo", "picture"]
                    ),
                    action: .insertImageFromFinder
                )
            )
        }
        if let alignAllAreasItem = alignAllAreasVerticallyCommandPaletteItem() {
            items.append(alignAllAreasItem)
        }
        return items
    }

    private func focusedNodeMarkdownToggleCommandPaletteItem() -> CommandPaletteItem? {
        guard
            let focusedNodeID = viewModel.focusedNodeID,
            viewModel.nodes.contains(where: { $0.id == focusedNodeID })
        else {
            return nil
        }

        let title = "Node: Toggle Markdown Style"
        let searchText =
            "markdown style toggle enable disable on off format heading list code block"
        return CommandPaletteItem(
            id: "toggleFocusedNodeMarkdownStyle",
            title: title,
            shortcutLabel: "Focused Node",
            hasShortcutBinding: false,
            searchText: Self.commandPaletteSearchText(
                title: title,
                shortcutLabel: "Focused Node",
                searchTokens: searchText.components(separatedBy: " ")
            ),
            action: .shortcut(.apply(commands: [.toggleFocusedNodeMarkdownStyle]))
        )
    }

    private func alignAllAreasVerticallyCommandPaletteItem() -> CommandPaletteItem? {
        guard viewModel.focusedNodeID != nil else {
            return nil
        }
        return CommandPaletteItem(
            id: "alignAllAreasVertically",
            title: "Area: Align All Areas Vertically",
            shortcutLabel: "Focused Area",
            hasShortcutBinding: false,
            searchText: Self.commandPaletteSearchText(
                title: "Area: Align All Areas Vertically",
                shortcutLabel: "Focused Area",
                searchTokens: ["align", "all", "areas", "vertical", "left", "line", "tree", "diagram"]
            ),
            action: .shortcut(.apply(commands: [.alignAllAreasVertically]))
        )
    }

    private func edgeDeletionCommandPaletteItem() -> CommandPaletteItem? {
        guard let command = edgeDeletionCommandFromCurrentState() else {
            return nil
        }
        let title = "Edge: Delete Selected"
        return CommandPaletteItem(
            id: "deleteSelectedOrFocusedEdges",
            title: title,
            shortcutLabel: "⌫",
            searchText: Self.commandPaletteSearchText(
                title: title,
                shortcutLabel: "⌫",
                searchTokens: ["edge", "delete", "selected", "remove", "connection", "line"]
            ),
            action: .deleteSelectedOrFocusedEdges(command)
        )
    }

    private func edgeDirectionalityCommandPaletteItem() -> CommandPaletteItem? {
        guard let command = edgeDirectionalityCycleCommandFromCurrentState() else {
            return nil
        }
        let title = "Edge: Cycle Directionality"
        return CommandPaletteItem(
            id: "cycleFocusedEdgeDirectionality",
            title: title,
            shortcutLabel: "⌘;",
            searchText: Self.commandPaletteSearchText(
                title: title,
                shortcutLabel: "⌘;",
                searchTokens: ["edge", "direction", "directionality", "arrow", "reverse", "cycle"]
            ),
            action: .cycleFocusedEdgeDirectionality(command)
        )
    }

    func executeSelectedCommandIfNeeded() {
        let commandItems = filteredCommandPaletteItems()
        guard !commandItems.isEmpty else {
            return
        }
        let selectedIndex = min(max(0, selectedCommandPaletteIndex), commandItems.count - 1)
        executeSelectedCommand(commandItems[selectedIndex])
    }

    func executeSelectedCommand(_ item: CommandPaletteItem) {
        markCommandPaletteQueryAsRecentlyUsed(commandPaletteQuery)
        switch item.action {
        case .shortcut(let shortcutAction):
            if !executeCommandPaletteShortcutAction(shortcutAction) {
                return
            }
        case .deleteSelectedOrFocusedEdges(let command):
            Task {
                await viewModel.apply(commands: [command])
            }
        case .cycleFocusedEdgeDirectionality(let command):
            Task {
                await viewModel.apply(commands: [command])
            }
        case .insertImageFromFinder:
            insertImageFromFinder()
        }
        markCommandPaletteItemAsRecentlyUsed(itemID: item.id)
        closeCommandPalette()
    }

    private func executeCommandPaletteShortcutAction(_ shortcutAction: CanvasShortcutAction) -> Bool {
        switch shortcutAction {
        case .apply(let commands):
            let commandContext = keymapExecutionContextForCommandPalette()
            let commandAction: KeymapContextAction = .apply(commands: commands)
            guard Self.isActionEnabled(commandAction, context: commandContext) else {
                return true
            }
            // Keep add-node behavior aligned with the shortcut route (mode-selection popup).
            if commands.count == 1, commands[0] == .addNode {
                let addNodeAction: KeymapContextAction = .presentAddNodeModeSelection
                guard Self.isActionEnabled(addNodeAction, context: commandContext) else {
                    return true
                }
                presentAddNodeModeSelectionPopup()
                return true
            }
            if Self.shouldExecuteCommandViaEdgeTarget(commands: commands, context: commandContext) {
                if handleEdgeTargetCommands(commands: commands) {
                    return true
                }
                return true
            }
            Task {
                await viewModel.apply(commands: commands)
            }
            return true
        case .undo:
            Task {
                await viewModel.undo()
            }
            return true
        case .redo:
            Task {
                await viewModel.redo()
            }
            return true
        case .zoomIn:
            applyZoom(action: .zoomIn)
            return true
        case .zoomOut:
            applyZoom(action: .zoomOut)
            return true
        case .beginConnectNodeSelection:
            presentConnectNodeSelectionIfPossible()
            return true
        case .openCommandPalette:
            return false
        }
    }

    private func matchesCommandPaletteQuery(_ value: String, _ rawQuery: String) -> Bool {
        let valueText = value.lowercased()
        let query = rawQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }

        var valueIndex = valueText.startIndex
        for queryCharacter in query {
            while valueIndex != valueText.endIndex, valueText[valueIndex] != queryCharacter {
                valueIndex = valueText.index(after: valueIndex)
            }
            guard valueIndex != valueText.endIndex else {
                return false
            }
            valueIndex = valueText.index(after: valueIndex)
        }
        return true
    }

    static func commandPaletteSearchText(
        title: String,
        shortcutLabel: String,
        searchTokens: [String]
    ) -> String {
        ([title, shortcutLabel] + searchTokens + commandPaletteVerbFirstAliases(from: title)).joined(
            separator: " "
        )
    }

    static func commandPaletteVerbFirstAliases(from title: String) -> [String] {
        let components = title.split(separator: ":", maxSplits: 1).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard components.count == 2 else {
            return []
        }

        let noun = components[0]
        let verb = components[1]
        guard !noun.isEmpty, !verb.isEmpty else {
            return []
        }
        return ["\(verb) \(noun)"]
    }

    static func commandPaletteItemsPrioritizingRecent(
        _ items: [CommandPaletteItem],
        recentItemIDs: [String],
        maxPinnedCount: Int
    ) -> [CommandPaletteItem] {
        let pinnedIDs = Array(recentItemIDs.prefix(maxPinnedCount))
        guard !pinnedIDs.isEmpty else {
            return items
        }

        let pinnedIndexByID = Dictionary(
            uniqueKeysWithValues: pinnedIDs.enumerated().map { ($0.element, $0.offset) }
        )
        let pinnedItems =
            items
            .filter { pinnedIndexByID[$0.id] != nil }
            .sorted { lhs, rhs in
                (pinnedIndexByID[lhs.id] ?? Int.max) < (pinnedIndexByID[rhs.id] ?? Int.max)
            }
        let remainingItems = items.filter { pinnedIndexByID[$0.id] == nil }
        return pinnedItems + remainingItems
    }

    private func commandPaletteContext() -> CanvasCommandPaletteContext {
        CanvasCommandPaletteContext(
            activeEditingMode: commandPaletteActiveEditingMode(),
            hasFocusedNode: viewModel.focusedNodeID != nil
        )
    }

    func commandPaletteActiveEditingMode() -> CanvasEditingMode? {
        if let focusedNodeID = viewModel.focusedNodeID {
            if viewModel.diagramNodeIDs.contains(focusedNodeID) {
                return .diagram
            }
            if viewModel.nodes.contains(where: { $0.id == focusedNodeID }) {
                return .tree
            }
        }

        let areaModes = Set(viewModel.areaEditingModeByID.values)
        if areaModes.count == 1 {
            return areaModes.first
        }
        return nil
    }

    private func keymapExecutionContextForCommandPalette() -> KeymapExecutionContext {
        KeymapExecutionContext(
            editingMode: commandPaletteActiveEditingMode(),
            operationTargetKind: operationTargetKind,
            hasFocusedNode: viewModel.focusedNodeID != nil,
            isEditingText: editingContext != nil,
            isCommandPalettePresented: isCommandPalettePresented,
            isSearchPresented: isSearchPresented,
            isConnectNodeSelectionActive: isConnectNodeSelectionActive(),
            isAddNodePopupPresented: isAddNodeModePopupPresented,
            selectedNodeCount: viewModel.selectedNodeIDs.count,
            selectedEdgeCount: viewModel.selectedEdgeIDs.count
        )
    }
}
