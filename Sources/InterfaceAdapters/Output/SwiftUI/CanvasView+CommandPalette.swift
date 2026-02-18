// Background: Command palette interactions need isolated key handling and filtering helpers.
// Responsibility: Provide command palette behavior for keyboard handling and action dispatch.
import AppKit
import Domain
import Foundation

extension CanvasView {
    struct CommandPaletteItem: Identifiable, Equatable {
        let id: String
        let title: String
        let shortcutLabel: String
        let searchText: String
        let action: CanvasShortcutAction
    }

    private static let commandPaletteEscapeKeyCode: UInt16 = 53
    private static let commandPaletteReturnKeyCode: UInt16 = 36
    private static let commandPaletteUpArrowKeyCode: UInt16 = 126
    private static let commandPaletteDownArrowKeyCode: UInt16 = 125
    private static let commandPaletteControlPKeyCode: UInt16 = 35
    private static let commandPaletteControlNKeyCode: UInt16 = 45
    private static let commandPaletteBackspaceKeyCode: UInt16 = 51
    private static let commandPaletteForwardDeleteKeyCode: UInt16 = 117

    func openCommandPalette() {
        isCommandPalettePresented = true
        selectedCommandPaletteIndex = 0
        commandPaletteQuery = ""
    }

    func closeCommandPalette() {
        isCommandPalettePresented = false
    }

    func handleCommandPaletteKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode

        if keyCode == Self.commandPaletteEscapeKeyCode {
            closeCommandPalette()
            return true
        }
        if keyCode == Self.commandPaletteReturnKeyCode {
            executeSelectedCommandIfNeeded()
            return true
        }
        if handlePaletteNavigationKeys(keyCode: keyCode, modifiers: event.modifierFlags) {
            return true
        }
        if handlePaletteDeletionKeys(keyCode: keyCode) {
            return true
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .function]
        guard modifiers.isDisjoint(with: disallowed) else {
            return true
        }

        guard let characters = event.charactersIgnoringModifiers, let first = characters.first else {
            return false
        }
        guard first != "\r", first != "\n" else {
            return true
        }
        guard first.isASCII, first.isLetter || first.isNumber || first.isPunctuation || first == " " else {
            // Ignore non-printable and function-key artifacts so query filtering stays stable.
            return true
        }
        commandPaletteQuery.append(contentsOf: String(first).lowercased())
        return true
    }

    private func handlePaletteNavigationKeys(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) -> Bool {
        if keyCode == Self.commandPaletteUpArrowKeyCode
            || (modifiers.contains(.control) && keyCode == Self.commandPaletteControlPKeyCode)
        {
            movePaletteSelection(offset: -1)
            return true
        }
        if keyCode == Self.commandPaletteDownArrowKeyCode
            || (modifiers.contains(.control) && keyCode == Self.commandPaletteControlNKeyCode)
        {
            movePaletteSelection(offset: 1)
            return true
        }
        return false
    }

    private func movePaletteSelection(offset: Int) {
        let items = filteredCommandPaletteItems()
        guard !items.isEmpty else {
            return
        }
        let maxIndex = max(0, items.count - 1)
        selectedCommandPaletteIndex = min(maxIndex, max(0, selectedCommandPaletteIndex + offset))
    }

    private func handlePaletteDeletionKeys(keyCode: UInt16) -> Bool {
        let deletionKeys: Set<UInt16> = [Self.commandPaletteBackspaceKeyCode, Self.commandPaletteForwardDeleteKeyCode]
        guard deletionKeys.contains(keyCode) else {
            return false
        }
        guard !commandPaletteQuery.isEmpty else {
            return true
        }
        commandPaletteQuery.removeLast()
        return true
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
        CanvasShortcutCatalogService.commandPaletteDefinitions().compactMap { definition in
            guard definition.isVisibleInCommandPalette else {
                return nil
            }
            let searchText = ([definition.name, definition.shortcutLabel] + definition.searchTokens).joined(
                separator: " "
            )
            return CommandPaletteItem(
                id: definition.id.rawValue,
                title: definition.name,
                shortcutLabel: definition.shortcutLabel,
                searchText: searchText,
                action: definition.action
            )
        }
    }

    private func executeSelectedCommandIfNeeded() {
        let commandItems = filteredCommandPaletteItems()
        guard !commandItems.isEmpty else {
            return
        }
        let selectedIndex = min(max(0, selectedCommandPaletteIndex), commandItems.count - 1)
        executeSelectedCommand(commandItems[selectedIndex])
    }

    func executeSelectedCommand(_ item: CommandPaletteItem) {
        switch item.action {
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
        case .openCommandPalette:
            return
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
