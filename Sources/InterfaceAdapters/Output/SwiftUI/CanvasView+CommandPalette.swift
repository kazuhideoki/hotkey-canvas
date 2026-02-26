// Background: Command palette interactions need isolated key handling and filtering helpers.
// Responsibility: Provide command palette behavior for keyboard handling and action dispatch.
import Domain
import Foundation

extension CanvasView {
    enum CommandPaletteAction: Equatable {
        case shortcut(CanvasShortcutAction)
        case insertImageFromFinder
    }

    struct CommandPaletteItem: Identifiable, Equatable {
        let id: String
        let title: String
        let shortcutLabel: String
        let searchText: String
        let action: CommandPaletteAction
    }

    func openCommandPalette() {
        isSearchPresented = false
        searchFocusedMatch = nil
        isCommandPalettePresented = true
        selectedCommandPaletteIndex = 0
        commandPaletteQuery = ""
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

        guard !commandPaletteQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return orderedItems
        }

        return orderedItems.filter { item in
            matchesCommandPaletteQuery(item.searchText, commandPaletteQuery)
        }
    }

    private func defaultCommandPaletteItems() -> [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []
        for definition in CanvasShortcutCatalogService.commandPaletteDefinitions() {
            guard definition.isVisibleInCommandPalette else {
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
        if let markdownToggleItem = focusedNodeMarkdownToggleCommandPaletteItem() {
            items.append(markdownToggleItem)
        }
        items.append(
            CommandPaletteItem(
                id: "insertImageFromFinder",
                title: "Image: Insert From Finder",
                shortcutLabel: "Finder",
                searchText: Self.commandPaletteSearchText(
                    title: "Image: Insert From Finder",
                    shortcutLabel: "Finder",
                    searchTokens: ["insert", "image", "finder", "photo", "picture"]
                ),
                action: .insertImageFromFinder
            )
        )
        if let alignParentNodesItem = alignParentNodesVerticallyCommandPaletteItem() {
            items.append(alignParentNodesItem)
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
            searchText: Self.commandPaletteSearchText(
                title: title,
                shortcutLabel: "Focused Node",
                searchTokens: searchText.components(separatedBy: " ")
            ),
            action: .shortcut(.apply(commands: [.toggleFocusedNodeMarkdownStyle]))
        )
    }

    private func alignParentNodesVerticallyCommandPaletteItem() -> CommandPaletteItem? {
        guard viewModel.focusedNodeID != nil else {
            return nil
        }
        return CommandPaletteItem(
            id: "alignParentNodesVertically",
            title: "Node: Align Parents Vertically",
            shortcutLabel: "Focused Area",
            searchText: Self.commandPaletteSearchText(
                title: "Node: Align Parents Vertically",
                shortcutLabel: "Focused Area",
                searchTokens: ["align", "parent", "nodes", "vertical", "left", "line", "tree", "diagram"]
            ),
            action: .shortcut(.apply(commands: [.alignParentNodesVertically]))
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
        switch item.action {
        case .shortcut(let shortcutAction):
            switch shortcutAction {
            case .apply(let commands):
                Task {
                    await viewModel.apply(commands: commands)
                }
            case .undo:
                Task {
                    await viewModel.undo()
                }
            case .redo:
                Task {
                    await viewModel.redo()
                }
            case .zoomIn:
                applyZoom(action: .zoomIn)
            case .zoomOut:
                applyZoom(action: .zoomOut)
            case .beginConnectNodeSelection:
                presentConnectNodeSelectionIfPossible()
            case .openCommandPalette:
                return
            }
        case .insertImageFromFinder:
            insertImageFromFinder()
        }
        closeCommandPalette()
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
}
