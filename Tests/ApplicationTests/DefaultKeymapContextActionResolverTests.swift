// Background: Primitive keymap route execution must preserve existing command behavior.
// Responsibility: Verify primitive intent to context-action mapping and unsupported no-op contract.
import Application
import Domain
import Testing

@Test("primary add は addSiblingNode(.below) コマンドにマップされる")
func test_resolve_primaryAdd_returnsAddSiblingBelow() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .add(variant: .primary))

    #expect(action == .apply(commands: [.addSiblingNode(position: .below)]))
}

@Test("エッジ ターゲット スイッチは switch-target-kind アクションにマップされる")
func test_resolve_switchTargetKindEdge_returnsSwitchTargetKindAction() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .switchTargetKind(variant: .edge))

    #expect(action == .switchTargetKind(variant: .edge))
}

@Test("サイクル ターゲット スイッチは、switch-target-kind アクションにマップされる")
func test_resolve_switchTargetKindCycle_returnsSwitchTargetKindAction() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .switchTargetKind(variant: .cycle))

    #expect(action == .switchTargetKind(variant: .cycle))
}

@Test("エリアターゲットスイッチはスイッチターゲット種類アクションにマップされる")
func test_resolve_switchTargetKindArea_returnsSwitchTargetKindAction() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .switchTargetKind(variant: .area))

    #expect(action == .switchTargetKind(variant: .area))
}

@Test("拡張選択フォーカスのインテントが方向性を維持")
func test_resolve_moveFocusExtendSelection_returnsExtendSelectionCommand() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .moveFocus(direction: .up, variant: .extendSelection))

    #expect(action == .apply(commands: [.extendSelection(.up)]))
}

@Test("エリア間フォーカスのインテントは moveFocusAcrossAreasToRoot コマンドにマップされる")
func test_resolve_moveFocusAcrossAreasToRoot_returnsMoveFocusAcrossAreasToRootCommand() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .moveFocus(direction: .right, variant: .acrossAreasToRoot))

    #expect(action == .apply(commands: [.moveFocusAcrossAreasToRoot(.right)]))
}

@Test("scale-selection-up 変換は、scale-selected-nodes コマンドにマップされる")
func test_resolve_transformScaleSelectionUp_returnsScaleSelectedNodesUp() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .transform(variant: .scaleSelectionUp))

    #expect(action == .apply(commands: [.scaleSelectedNodes(.up)]))
}

@Test("area-edge-shape コマンドへの編集マップの切り替え")
func test_resolve_editToggleFocusedAreaEdgeShapeStyle_returnsToggleFocusedAreaEdgeShapeStyle() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .edit(variant: .toggleFocusedAreaEdgeShapeStyle))

    #expect(action == .apply(commands: [.toggleFocusedAreaEdgeShapeStyle]))
}

@Test("output インテントは reportUnsupportedIntent を返す")
func test_resolve_output_returnsReportUnsupportedIntent() {
    let sut = DefaultKeymapContextActionResolver()

    let action = sut.resolve(primitiveIntent: .output)

    #expect(action == .reportUnsupportedIntent(intent: .output))
}
