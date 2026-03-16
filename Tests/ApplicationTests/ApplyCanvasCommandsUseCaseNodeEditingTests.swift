import Domain
import Testing

@testable import Application

private func makeImageAttachment(path: String) -> CanvasAttachment {
    CanvasAttachment(
        id: CanvasAttachmentID(rawValue: "attachment-image-above-text"),
        kind: .image(filePath: path),
        placement: .aboveText
    )
}

@Test("setNodeText はターゲット ノードを更新し、空を nil に正規化し、高さを保持する")
func test_apply_setNodeText_updatesNodeText() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let updated = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after", nodeHeight: 48)]
    )
    #expect(updated.newState.nodesByID[nodeID]?.text == "after")
    #expect(updated.newState.nodesByID[nodeID]?.bounds.height == 48)

    let cleared = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "", nodeHeight: 44)]
    )
    #expect(cleared.newState.nodesByID[nodeID]?.text == nil)
    #expect(cleared.newState.nodesByID[nodeID]?.bounds.height == 44)
}

@Test("setNodeText は非有限の高さの値を拒否する")
func test_apply_setNodeText_nonFiniteHeight_fallsBackToCurrentHeight() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 70)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let nanHeightResult = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after-nan", nodeHeight: .nan)]
    )
    #expect(nanHeightResult.newState.nodesByID[nodeID]?.text == "after-nan")
    #expect(nanHeightResult.newState.nodesByID[nodeID]?.bounds.height == 70)

    let infinityHeightResult = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after-inf", nodeHeight: .infinity)]
    )
    #expect(infinityHeightResult.newState.nodesByID[nodeID]?.text == "after-inf")
    #expect(infinityHeightResult.newState.nodesByID[nodeID]?.bounds.height == 70)
}

@Test("setNodeText は行の増加に応じてノードの高さを拡張する")
func test_apply_setNodeText_expandsNodeHeightAsLinesIncrease() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())
    let twentyLines = Array(repeating: "line", count: 20).joined(separator: "\n")
    let fortyLines = Array(repeating: "line", count: 40).joined(separator: "\n")
    let twentyLineHeightInput = 420.0
    let fortyLineHeightInput = 760.0

    let twentyLineResult = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: twentyLines, nodeHeight: twentyLineHeightInput)]
    )
    let twentyLineHeight = try #require(twentyLineResult.newState.nodesByID[nodeID]?.bounds.height)
    #expect(twentyLineHeight == twentyLineHeightInput)

    let fortyLineResult = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: fortyLines, nodeHeight: fortyLineHeightInput)]
    )
    let fortyLineHeight = try #require(fortyLineResult.newState.nodesByID[nodeID]?.bounds.height)
    #expect(fortyLineHeight == fortyLineHeightInput)
    #expect(fortyLineHeight > twentyLineHeight)
}

@Test("setNodeText は行が減少するとノードの高さを縮小する")
func test_apply_setNodeText_shrinksNodeHeightWhenLinesDecrease() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())
    let fortyLines = Array(repeating: "line", count: 40).joined(separator: "\n")
    let expandedHeightInput = 760.0
    let shrunkHeightInput = 120.0

    let expanded = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: fortyLines, nodeHeight: expandedHeightInput)]
    )
    let expandedHeight = try #require(expanded.newState.nodesByID[nodeID]?.bounds.height)
    #expect(expandedHeight == expandedHeightInput)

    let shrunk = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "line", nodeHeight: shrunkHeightInput)]
    )
    let shrunkHeight = try #require(shrunk.newState.nodesByID[nodeID]?.bounds.height)
    #expect(shrunkHeight == shrunkHeightInput)
    #expect(shrunkHeight < expandedHeight)
}

@Test("setNodeText は、ダイアグラムノードをツリー幅の辺の長さを持つ正方形として維持する")
func test_apply_setNodeText_inDiagramArea_keepsSquareNode() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 120)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let updated = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after", nodeHeight: 512)]
    )
    let updatedNode = try #require(updated.newState.nodesByID[nodeID])
    #expect(updatedNode.text == "after")
    #expect(updatedNode.bounds.width == 220)
    #expect(updatedNode.bounds.height == 220)
}

@Test("setNodeText は、ダイアグラム イメージ ノードの辺の長さをアタッチメント範囲内に保ちます")
func test_apply_setNodeText_inDiagramAreaWithImage_preservesExpandedSquareSide() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-image-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                attachments: [makeImageAttachment(path: "/tmp/diagram-image.png")],
                bounds: CanvasBounds(x: 0, y: 0, width: 300, height: 300)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let updated = try await sut.apply(
        commands: [.setNodeText(nodeID: nodeID, text: "after", nodeHeight: 512)]
    )
    let updatedNode = try #require(updated.newState.nodesByID[nodeID])
    #expect(updatedNode.bounds.width == 300)
    #expect(updatedNode.bounds.height == 300)
}

@Test("upsertNodeAttachment はターゲット ノードのイメージの添付ファイルと高さを更新する")
func test_apply_upsertNodeAttachment_updatesNodeImage() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let updated = try await sut.apply(
        commands: [
            .upsertNodeAttachment(
                nodeID: nodeID,
                attachment: makeImageAttachment(path: "/tmp/image-1.png"),
                nodeWidth: 100,
                nodeHeight: 84
            )
        ]
    )
    #expect(updated.newState.nodesByID[nodeID]?.primaryImageAttachmentFilePath == "/tmp/image-1.png")
    #expect(updated.newState.nodesByID[nodeID]?.bounds.height == 84)
    #expect(updated.newState.nodesByID[nodeID]?.text == "before")
}

@Test("upsertNodeAttachment は、再度挿入するときに既存の画像を置き換えます")
func test_apply_upsertNodeAttachment_replacesExistingImage() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                attachments: [makeImageAttachment(path: "/tmp/old.png")],
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let replaced = try await sut.apply(
        commands: [
            .upsertNodeAttachment(
                nodeID: nodeID,
                attachment: makeImageAttachment(path: "/tmp/new.jpeg"),
                nodeWidth: 100,
                nodeHeight: 90
            )
        ]
    )
    #expect(replaced.newState.nodesByID[nodeID]?.primaryImageAttachmentFilePath == "/tmp/new.jpeg")
    #expect(replaced.newState.nodesByID[nodeID]?.bounds.height == 90)
}

@Test("upsertNodeAttachment は非有限の高さの値を拒否する")
func test_apply_upsertNodeAttachment_nonFiniteHeight_fallsBackToCurrentHeight() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 70)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let nanHeightResult = try await sut.apply(
        commands: [
            .upsertNodeAttachment(
                nodeID: nodeID,
                attachment: makeImageAttachment(path: "/tmp/image-2.webp"),
                nodeWidth: 100,
                nodeHeight: .nan
            )
        ]
    )
    #expect(nanHeightResult.newState.nodesByID[nodeID]?.primaryImageAttachmentFilePath == "/tmp/image-2.webp")
    #expect(nanHeightResult.newState.nodesByID[nodeID]?.bounds.height == 70)

    let infinityHeightResult = try await sut.apply(
        commands: [
            .upsertNodeAttachment(
                nodeID: nodeID,
                attachment: makeImageAttachment(path: "/tmp/image-3.heic"),
                nodeWidth: 100,
                nodeHeight: .infinity
            )
        ]
    )
    #expect(infinityHeightResult.newState.nodesByID[nodeID]?.primaryImageAttachmentFilePath == "/tmp/image-3.heic")
    #expect(infinityHeightResult.newState.nodesByID[nodeID]?.bounds.height == 70)
}

@Test("upsertNodeAttachment は図のノードを正方形に保ち、画像範囲ごとに固定する")
func test_apply_upsertNodeAttachment_inDiagramArea_clampsNodeSide() async throws {
    let nodeID = CanvasNodeID(rawValue: "diagram-node")
    let areaID = CanvasAreaID(rawValue: "diagram-area")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 220)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID,
        areasByID: [
            areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
        ]
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let updated = try await sut.apply(
        commands: [
            .upsertNodeAttachment(
                nodeID: nodeID,
                attachment: makeImageAttachment(path: "/tmp/diagram-image-large.png"),
                nodeWidth: 999,
                nodeHeight: 999
            )
        ]
    )
    let updatedNode = try #require(updated.newState.nodesByID[nodeID])
    #expect(updatedNode.bounds.width == CanvasDefaultNodeDistance.diagramImageMaxSide)
    #expect(updatedNode.bounds.height == CanvasDefaultNodeDistance.diagramImageMaxSide)
}

@Test("addNode はデフォルトでマークダウン スタイルを有効にする")
func test_apply_addNode_enablesMarkdownStylingByDefault() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let result = try await sut.apply(commands: [.addNode])
    let focusedNodeID = try #require(result.newState.focusedNodeID)
    let addedNode = try #require(result.newState.nodesByID[focusedNodeID])

    #expect(addedNode.markdownStyleEnabled)
}

@Test("toggleFocusedNodeMarkdownStyle はフォーカス中のノードのマークダウン フラグを切り替える")
func test_apply_toggleFocusedNodeMarkdownStyle_togglesFocusedNodeFlag() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "# heading",
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 70),
                markdownStyleEnabled: true
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let disabledResult = try await sut.apply(commands: [.toggleFocusedNodeMarkdownStyle])
    #expect(disabledResult.newState.nodesByID[nodeID]?.markdownStyleEnabled == false)

    let enabledResult = try await sut.apply(commands: [.toggleFocusedNodeMarkdownStyle])
    #expect(enabledResult.newState.nodesByID[nodeID]?.markdownStyleEnabled == true)
}

@Test("toggleFocusedNodeMarkdownStyle は画像の添付ファイルを保存し、再レイアウトを要求する")
func test_applyMutation_toggleFocusedNodeMarkdownStyle_preservesImageAttachment_andRequestsRelayout() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "# heading",
                attachments: [makeImageAttachment(path: "/tmp/current-image.png")],
                bounds: CanvasBounds(x: 0, y: 0, width: 220, height: 70),
                markdownStyleEnabled: true
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    ).withDefaultTreeAreaIfMissing()
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph)

    let mutationResult = try await sut.applyMutation(
        command: .toggleFocusedNodeMarkdownStyle,
        to: graph
    )

    #expect(
        mutationResult.graphAfterMutation.nodesByID[nodeID]?.primaryImageAttachmentFilePath == "/tmp/current-image.png")
    #expect(mutationResult.graphAfterMutation.nodesByID[nodeID]?.markdownStyleEnabled == false)
    #expect(mutationResult.effects.didMutateGraph)
    #expect(mutationResult.effects.needsTreeLayout)
    #expect(mutationResult.effects.needsAreaLayout)
    #expect(!mutationResult.effects.needsFocusNormalization)
    #expect(mutationResult.areaLayoutSeedNodeID == nodeID)
}
