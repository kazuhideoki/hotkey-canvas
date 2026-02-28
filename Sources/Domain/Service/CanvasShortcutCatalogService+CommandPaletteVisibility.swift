// Background: Command palette listing needs one place to evaluate runtime visibility conditions.
// Responsibility: Keep visibility predicate logic separate from static shortcut definition data.
extension CanvasShortcutCatalogService {
    static func commandPaletteVisibilityMatches(
        _ visibility: CanvasCommandPaletteVisibility,
        context: CanvasCommandPaletteContext
    ) -> Bool {
        switch visibility {
        case .always:
            return true
        case .requiresFocusedNode:
            return context.hasFocusedNode
        case .requiresMode(let modes):
            guard let mode = context.activeEditingMode else {
                return false
            }
            return modes.contains(mode)
        case .requiresFocusedNodeAndMode(let modes):
            guard context.hasFocusedNode, let mode = context.activeEditingMode else {
                return false
            }
            return modes.contains(mode)
        }
    }
}
