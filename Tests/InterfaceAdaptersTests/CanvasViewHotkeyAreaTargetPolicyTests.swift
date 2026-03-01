import Application
import Domain
import Testing

@testable import InterfaceAdapters

@Test("CanvasView area-target policy: blocks global node/edge-target actions")
func test_blocksGlobalActionInAreaTarget_blocksNodeOrEdgeActions() {
    #expect(CanvasView.blocksGlobalActionInAreaTarget(.beginConnectNodeSelection))
    #expect(CanvasView.blocksGlobalActionInAreaTarget(.centerFocusedNode))
    #expect(!CanvasView.blocksGlobalActionInAreaTarget(.undo))
}

@Test("CanvasView area-target policy: blocks node and edge commands, allows area focus move")
func test_blocksCommandInAreaTarget_blocksNodeAndEdgeCommands() {
    #expect(CanvasView.blocksCommandInAreaTarget(.addSiblingNode(position: .below)))
    #expect(CanvasView.blocksCommandInAreaTarget(.moveNode(.right)))
    #expect(CanvasView.blocksCommandInAreaTarget(.deleteSelectedOrFocusedNodes))
    #expect(
        CanvasView.blocksCommandInAreaTarget(
            .deleteSelectedOrFocusedEdges(
                focusedEdge: CanvasEdgeFocus(
                    edgeID: CanvasEdgeID(rawValue: "edge"),
                    originNodeID: CanvasNodeID(rawValue: "node")
                ),
                selectedEdgeIDs: []
            )
        )
    )
    #expect(!CanvasView.blocksCommandInAreaTarget(.moveFocus(.up)))
}

@Test("CanvasView area-target policy: blocks primitive edge/node target actions")
func test_blocksPrimitiveContextActionInAreaTarget_blocksNodeAndEdgeActions() {
    #expect(
        CanvasView.blocksPrimitiveContextActionInAreaTarget(
            .apply(commands: [.moveNode(.left)])
        )
    )
    #expect(
        !CanvasView.blocksPrimitiveContextActionInAreaTarget(
            .apply(commands: [.moveFocus(.left)])
        )
    )
    #expect(CanvasView.blocksPrimitiveContextActionInAreaTarget(.cycleFocusedEdgeDirectionality))
    #expect(CanvasView.blocksPrimitiveContextActionInAreaTarget(.presentAddNodeModeSelection))
    #expect(
        !CanvasView.blocksPrimitiveContextActionInAreaTarget(
            .switchTargetKind(variant: .node)
        )
    )
}

@Test("CanvasView area-target policy: command palette hides node/edge shortcuts in area target")
func test_isCommandPaletteShortcutHiddenInAreaTarget_hidesNodeOrEdgeShortcuts() {
    #expect(
        CanvasView.isCommandPaletteShortcutHiddenInAreaTarget(
            .apply(commands: [.addNode])
        )
    )
    #expect(
        CanvasView.isCommandPaletteShortcutHiddenInAreaTarget(
            .apply(commands: [.centerFocusedNode])
        )
    )
    #expect(
        CanvasView.isCommandPaletteShortcutHiddenInAreaTarget(
            .beginConnectNodeSelection
        )
    )
    #expect(!CanvasView.isCommandPaletteShortcutHiddenInAreaTarget(.undo))
}
