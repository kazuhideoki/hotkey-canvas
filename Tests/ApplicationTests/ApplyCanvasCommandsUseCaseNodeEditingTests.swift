import Domain
import Testing

@testable import Application

@Test("ApplyCanvasCommandsUseCase: setNodeText updates target node, normalizes empty to nil, and persists height")
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

@Test("ApplyCanvasCommandsUseCase: setNodeText rejects non-finite height values")
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

@Test("ApplyCanvasCommandsUseCase: setNodeText expands node height as lines increase")
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

@Test("ApplyCanvasCommandsUseCase: setNodeText shrinks node height when lines decrease")
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

@Test("ApplyCanvasCommandsUseCase: setNodeText keeps diagram node as square with tree-width side length")
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

@Test("ApplyCanvasCommandsUseCase: setNodeImage updates target node image path and height")
func test_apply_setNodeImage_updatesNodeImage() async throws {
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
        commands: [.setNodeImage(nodeID: nodeID, imagePath: "/tmp/image-1.png", nodeHeight: 84)]
    )
    #expect(updated.newState.nodesByID[nodeID]?.imagePath == "/tmp/image-1.png")
    #expect(updated.newState.nodesByID[nodeID]?.bounds.height == 84)
    #expect(updated.newState.nodesByID[nodeID]?.text == "before")
}

@Test("ApplyCanvasCommandsUseCase: setNodeImage replaces existing image when inserting again")
func test_apply_setNodeImage_replacesExistingImage() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                imagePath: "/tmp/old.png",
                bounds: CanvasBounds(x: 0, y: 0, width: 100, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let sut = ApplyCanvasCommandsUseCase(initialGraph: graph.withDefaultTreeAreaIfMissing())

    let replaced = try await sut.apply(
        commands: [.setNodeImage(nodeID: nodeID, imagePath: "/tmp/new.jpeg", nodeHeight: 90)]
    )
    #expect(replaced.newState.nodesByID[nodeID]?.imagePath == "/tmp/new.jpeg")
    #expect(replaced.newState.nodesByID[nodeID]?.bounds.height == 90)
}

@Test("ApplyCanvasCommandsUseCase: setNodeImage rejects non-finite height values")
func test_apply_setNodeImage_nonFiniteHeight_fallsBackToCurrentHeight() async throws {
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
        commands: [.setNodeImage(nodeID: nodeID, imagePath: "/tmp/image-2.webp", nodeHeight: .nan)]
    )
    #expect(nanHeightResult.newState.nodesByID[nodeID]?.imagePath == "/tmp/image-2.webp")
    #expect(nanHeightResult.newState.nodesByID[nodeID]?.bounds.height == 70)

    let infinityHeightResult = try await sut.apply(
        commands: [.setNodeImage(nodeID: nodeID, imagePath: "/tmp/image-3.heic", nodeHeight: .infinity)]
    )
    #expect(infinityHeightResult.newState.nodesByID[nodeID]?.imagePath == "/tmp/image-3.heic")
    #expect(infinityHeightResult.newState.nodesByID[nodeID]?.bounds.height == 70)
}

@Test("ApplyCanvasCommandsUseCase: addNode enables markdown styling by default")
func test_apply_addNode_enablesMarkdownStylingByDefault() async throws {
    let sut = ApplyCanvasCommandsUseCase()

    let result = try await sut.apply(commands: [.addNode])
    let focusedNodeID = try #require(result.newState.focusedNodeID)
    let addedNode = try #require(result.newState.nodesByID[focusedNodeID])

    #expect(addedNode.markdownStyleEnabled)
}

@Test("ApplyCanvasCommandsUseCase: toggleFocusedNodeMarkdownStyle toggles markdown flag for focused node")
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

@Test("ApplyCanvasCommandsUseCase: toggleFocusedNodeMarkdownStyle preserves image path and requests relayout")
func test_applyMutation_toggleFocusedNodeMarkdownStyle_preservesImagePath_andRequestsRelayout() async throws {
    let nodeID = CanvasNodeID(rawValue: "node")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "# heading",
                imagePath: "/tmp/current-image.png",
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

    #expect(mutationResult.graphAfterMutation.nodesByID[nodeID]?.imagePath == "/tmp/current-image.png")
    #expect(mutationResult.graphAfterMutation.nodesByID[nodeID]?.markdownStyleEnabled == false)
    #expect(mutationResult.effects.didMutateGraph)
    #expect(mutationResult.effects.needsTreeLayout)
    #expect(mutationResult.effects.needsAreaLayout)
    #expect(!mutationResult.effects.needsFocusNormalization)
    #expect(mutationResult.areaLayoutSeedNodeID == nodeID)
}
