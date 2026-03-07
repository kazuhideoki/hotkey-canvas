import Domain
import Testing

// Background: Edge-target navigation commands rely on edge-aware execution routing from the shortcut catalog.
// Responsibility: Verify edge-target navigation definitions opt into edge-aware routing.
@Test("Shortcut catalog: edge-aware route is attached to edge-target navigation commands")
func test_commandPaletteDefinitions_attachEdgeAwareRouteToEdgeNavigationCommands() {
    let moveFocus = CanvasShortcutCatalogService.definition(for: .moveFocus(.up))
    let extendSelection = CanvasShortcutCatalogService.definition(for: .extendSelection(.left))
    let deleteSelected = CanvasShortcutCatalogService.definition(for: .deleteSelectedOrFocusedNodes)

    #expect(moveFocus != nil)
    #expect(extendSelection != nil)
    #expect(deleteSelected != nil)
    #expect(moveFocus?.executionRoute == .edgeAware)
    #expect(extendSelection?.executionRoute == .edgeAware)
    #expect(deleteSelected?.executionRoute == .edgeAware)
}
