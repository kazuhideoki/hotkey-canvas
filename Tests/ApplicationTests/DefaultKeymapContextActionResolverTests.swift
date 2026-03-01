// Background: Primitive keymap route execution must preserve existing command behavior.
// Responsibility: Verify primitive intent to context-action mapping and unsupported no-op contract.
import Application
import Domain
import Testing

@Test("DefaultKeymapContextActionResolver: primary add maps to add-sibling-below command")
func test_resolve_primaryAdd_returnsAddSiblingBelow() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .add(variant: .primary))

    #expect(action == .apply(commands: [.addSiblingNode(position: .below)]))
}

@Test("DefaultKeymapContextActionResolver: edge target switch maps to switch-target-kind action")
func test_resolve_switchTargetKindEdge_returnsSwitchTargetKindAction() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .switchTargetKind(variant: .edge))

    #expect(action == .switchTargetKind(variant: .edge))
}

@Test("DefaultKeymapContextActionResolver: cycle target switch maps to switch-target-kind action")
func test_resolve_switchTargetKindCycle_returnsSwitchTargetKindAction() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .switchTargetKind(variant: .cycle))

    #expect(action == .switchTargetKind(variant: .cycle))
}

@Test("DefaultKeymapContextActionResolver: area target switch maps to switch-target-kind action")
func test_resolve_switchTargetKindArea_returnsSwitchTargetKindAction() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .switchTargetKind(variant: .area))

    #expect(action == .switchTargetKind(variant: .area))
}

@Test("DefaultKeymapContextActionResolver: extend-selection focus intent keeps direction")
func test_resolve_moveFocusExtendSelection_returnsExtendSelectionCommand() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .moveFocus(direction: .up, variant: .extendSelection))

    #expect(action == .apply(commands: [.extendSelection(.up)]))
}

@Test("DefaultKeymapContextActionResolver: scale-selection-up transform maps to scale-selected-nodes command")
func test_resolve_transformScaleSelectionUp_returnsScaleSelectedNodesUp() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .transform(variant: .scaleSelectionUp))

    #expect(action == .apply(commands: [.scaleSelectedNodes(.up)]))
}

@Test("DefaultKeymapContextActionResolver: output intent returns unsupported contract")
func test_resolve_output_returnsReportUnsupportedIntent() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .output)

    #expect(action == .reportUnsupportedIntent(intent: .output))
}
