import Domain
import Testing

@Test("Shortcut catalog: command-shift-e resolves toggleFocusedAreaEdgeShapeStyle")
func test_resolveAction_commandShiftE_returnsToggleFocusedAreaEdgeShapeStyle() {
    let gesture = CanvasShortcutGesture(key: .character("e"), modifiers: [.command, .shift])

    let action = CanvasShortcutCatalogService.resolveAction(for: gesture)

    #expect(action == .apply(commands: [.toggleFocusedAreaEdgeShapeStyle]))
}
