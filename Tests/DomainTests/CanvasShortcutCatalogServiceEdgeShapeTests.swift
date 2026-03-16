import Domain
import Testing

@Test("command-shift-e は toggleFocusedAreaEdgeShapeStyle を解決する")
func test_resolveAction_commandShiftE_returnsToggleFocusedAreaEdgeShapeStyle() {
    let gesture = CanvasShortcutGesture(key: .character("e"), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.toggleFocusedAreaEdgeShapeStyle]))
}
