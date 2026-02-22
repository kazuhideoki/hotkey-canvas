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
<<<<<<< HEAD
        let shortcutItems: [CommandPaletteItem] =
            CanvasShortcutCatalogService.commandPaletteDefinitions().map { definition in
                let searchText = ([definition.name, definition.shortcutLabel] + definition.searchTokens).joined(
                    separator: " "
                )
                return CommandPaletteItem(
                    id: definition.id.rawValue,
                    title: definition.name,
                    shortcutLabel: definition.shortcutLabel,
                    searchText: searchText,
                    action: .shortcut(definition.action)
                )
            }

        let imageInsertItem = CommandPaletteItem(
            id: "insertImageFromFinder",
            title: "Insert Image from Finder",
            shortcutLabel: "Finder",
            searchText: "insert image finder photo picture",
            action: .insertImageFromFinder
        )
        return shortcutItems + [imageInsertItem]
=======
        var items: [CommandPaletteItem] = []
        for definition in CanvasShortcutCatalogService.commandPaletteDefinitions() {
            guard definition.isVisibleInCommandPalette else {
                continue
            }
            let searchText = ([definition.name, definition.shortcutLabel] + definition.searchTokens).joined(
                separator: " "
            )
            items.append(
                CommandPaletteItem(
                    id: definition.id.rawValue,
                    title: definition.name,
                    shortcutLabel: definition.shortcutLabel,
                    searchText: searchText,
                    action: definition.action
                )
            )
        }
        if let markdownToggleItem = focusedNodeMarkdownToggleCommandPaletteItem() {
            items.append(markdownToggleItem)
        }
        return items
    }

    private func focusedNodeMarkdownToggleCommandPaletteItem() -> CommandPaletteItem? {
        guard
            let focusedNodeID = viewModel.focusedNodeID,
            let focusedNode = viewModel.nodes.first(where: { $0.id == focusedNodeID })
        else {
            return nil
        }

        let title =
            focusedNode.markdownStyleEnabled
            ? "Disable Markdown Style"
            : "Enable Markdown Style"
        let searchText = "markdown style toggle format heading list code block"
        return CommandPaletteItem(
            id: "toggleFocusedNodeMarkdownStyle",
            title: title,
            shortcutLabel: "Focused Node",
            searchText: searchText,
            action: .apply(commands: [.toggleFocusedNodeMarkdownStyle])
        )
>>>>>>> main
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

}
