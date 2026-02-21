// swiftlint:disable file_length
import Application
import Domain
import InterfaceAdapters
import Testing

@MainActor
@Test("CanvasViewModel: onAppear does not overwrite newer apply result")
func test_onAppear_doesNotOverwriteApplyResult() async throws {
    let inputPort = DelayedCanvasEditingInputPort(getDelayNanoseconds: 200_000_000)
    let viewModel = CanvasViewModel(inputPort: inputPort)

    let onAppearTask = Task { await viewModel.onAppear() }
    try await Task.sleep(nanoseconds: 20_000_000)
    await viewModel.apply(commands: [.addNode])
    _ = await onAppearTask.value

    #expect(viewModel.nodes.count == 1)
}

@MainActor
@Test("CanvasViewModel: onAppear creates initial node and returns editing target when graph is empty")
func test_onAppear_createsInitialNode_andReturnsEditingTarget() async throws {
    let inputPort = EmptyBootstrapCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    let initialEditingNodeID = await viewModel.onAppear()

    #expect(viewModel.nodes.count == 1)
    #expect(viewModel.focusedNodeID == CanvasNodeID(rawValue: "node-1"))
    #expect(initialEditingNodeID == CanvasNodeID(rawValue: "node-1"))
}

@MainActor
@Test("CanvasViewModel: onAppear does not add duplicate initial node during overlapping add")
func test_onAppear_avoidsDuplicateInitialNode_duringOverlappingAdd() async throws {
    let inputPort = OverlappingInitialNodeCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    let onAppearTask = Task { await viewModel.onAppear() }
    try await Task.sleep(nanoseconds: 20_000_000)
    let addTask = Task { await viewModel.apply(commands: [.addNode]) }

    await addTask.value
    _ = await onAppearTask.value

    #expect(viewModel.nodes.count == 1)
    #expect(await inputPort.nodeCount() == 1)
}

@MainActor
@Test("CanvasViewModel: onAppear refreshes from current result when bootstrap apply becomes stale")
func test_onAppear_refreshesCurrentResult_whenBootstrapApplyBecomesStale() async throws {
    let inputPort = StaleBootstrapApplyCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    let onAppearTask = Task { await viewModel.onAppear() }
    try await Task.sleep(nanoseconds: 20_000_000)
    let newerApplyTask = Task { await viewModel.apply(commands: [.moveFocus(.down)]) }
    await newerApplyTask.value
    await inputPort.releaseFirstApply()
    let initialEditingNodeID = await onAppearTask.value

    #expect(initialEditingNodeID == nil)
    #expect(viewModel.nodes.count == 1)
    #expect(viewModel.focusedNodeID == CanvasNodeID(rawValue: "node-1"))
}

@MainActor
@Test("CanvasViewModel: earlier successful apply is preserved when later overlapping apply fails")
func test_apply_preservesEarlierSuccess_whenLaterOverlappingApplyFails() async throws {
    let inputPort = OverlappingFailureCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    let firstApplyTask = Task { await viewModel.apply(commands: [.addNode]) }
    try await Task.sleep(nanoseconds: 20_000_000)
    let secondApplyTask = Task { await viewModel.apply(commands: [.addNode]) }
    try await Task.sleep(nanoseconds: 20_000_000)
    await inputPort.releaseFirstApply()

    await secondApplyTask.value
    await firstApplyTask.value

    #expect(viewModel.nodes.count == 1)
}

@MainActor
@Test("CanvasViewModel: newer overlapping successful apply stays visible")
func test_apply_keepsNewerSuccess_whenOlderCompletesLater() async throws {
    let inputPort = ReorderedSuccessCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    let firstApplyTask = Task { await viewModel.apply(commands: [.addNode]) }
    try await Task.sleep(nanoseconds: 20_000_000)
    let secondApplyTask = Task { await viewModel.apply(commands: [.addNode]) }
    await secondApplyTask.value
    await inputPort.releaseFirstApply()
    await firstApplyTask.value

    #expect(viewModel.nodes.count == 2)
    #expect(viewModel.focusedNodeID == CanvasNodeID(rawValue: "node-2"))
}

@MainActor
@Test("CanvasViewModel: undo and redo update history flags")
func test_undoRedo_updatesHistoryFlags() async throws {
    let inputPort = UndoRedoCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.apply(commands: [.addNode])
    #expect(viewModel.canUndo)
    #expect(!viewModel.canRedo)

    await viewModel.undo()
    #expect(!viewModel.canUndo)
    #expect(viewModel.canRedo)
    #expect(viewModel.nodes.isEmpty)

    await viewModel.redo()
    #expect(viewModel.canUndo)
    #expect(!viewModel.canRedo)
    #expect(viewModel.nodes.count == 1)
}

@MainActor
@Test("CanvasViewModel: undo result stays visible when older apply completes later")
func test_undo_keepsState_whenOlderApplyCompletesLater() async throws {
    let inputPort = ApplyUndoReorderCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    let applyTask = Task { await viewModel.apply(commands: [.addNode]) }
    try await Task.sleep(nanoseconds: 20_000_000)
    await viewModel.undo()
    await inputPort.releaseApply()
    await applyTask.value

    #expect(viewModel.nodes.isEmpty)
}

@MainActor
@Test("CanvasViewModel: onAppear reflects history flags from shared input port")
func test_onAppear_reflectsHistoryFlags() async throws {
    let inputPort = UndoRedoCanvasEditingInputPort()
    _ = try await inputPort.apply(commands: [.addNode])
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.onAppear()

    #expect(viewModel.canUndo)
    #expect(!viewModel.canRedo)
    #expect(viewModel.nodes.count == 1)
}

@MainActor
@Test("CanvasViewModel: onAppear hides folded descendants from published nodes and edges")
func test_onAppear_hidesFoldedDescendants_fromPublishedGraph() async throws {
    let rootID = CanvasNodeID(rawValue: "root")
    let childID = CanvasNodeID(rawValue: "child")
    let edgeID = CanvasEdgeID(rawValue: "edge-root-child")
    let graph = CanvasGraph(
        nodesByID: [
            rootID: CanvasNode(
                id: rootID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
            ),
            childID: CanvasNode(
                id: childID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 260, y: 0, width: 200, height: 100)
            ),
        ],
        edgesByID: [
            edgeID: CanvasEdge(
                id: edgeID,
                fromNodeID: rootID,
                toNodeID: childID,
                relationType: .parentChild
            )
        ],
        focusedNodeID: rootID,
        collapsedRootNodeIDs: [rootID]
    )
    let inputPort = StaticCanvasEditingInputPort(graph: graph)
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.onAppear()

    #expect(viewModel.nodes.map(\.id) == [rootID])
    #expect(viewModel.edges.isEmpty)
    #expect(viewModel.collapsedRootNodeIDs == [rootID])
}

@MainActor
@Test("CanvasViewModel: add-node apply publishes pending editing node")
func test_apply_addNode_setsPendingEditingNodeID() async throws {
    let inputPort = UndoRedoCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.apply(commands: [.addNode])

    #expect(viewModel.pendingEditingNodeID == CanvasNodeID(rawValue: "node-1"))
}

@MainActor
@Test("CanvasViewModel: mode-selected add-node with tree sets pending editing node")
func test_addNodeFromModeSelection_tree_setsPendingEditingNodeID() async throws {
    let inputPort = UndoRedoCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.addNodeFromModeSelection(mode: .tree)

    #expect(viewModel.nodes.count == 1)
    #expect(viewModel.pendingEditingNodeID == CanvasNodeID(rawValue: "node-1"))
}

@MainActor
@Test("CanvasViewModel: mode-selected add-node with tree creates tree area when focused area is diagram")
func test_addNodeFromModeSelection_tree_createsTreeAreaWhenFocusedAreaIsDiagram() async throws {
    let inputPort = TreeModeSelectionFromDiagramCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.addNodeFromModeSelection(mode: .tree)

    #expect(viewModel.pendingEditingNodeID == CanvasNodeID(rawValue: "node-2"))
    let graph = await inputPort.getCurrentGraph()
    let addedNodeID = CanvasNodeID(rawValue: "node-2")
    let addedAreaID = try CanvasAreaMembershipService.areaID(containing: addedNodeID, in: graph).get()
    let addedArea = try CanvasAreaMembershipService.area(withID: addedAreaID, in: graph).get()
    #expect(addedArea.editingMode == .tree)
}

@MainActor
@Test("CanvasViewModel: mode-selected add-node with diagram creates new diagram area for added node")
func test_addNodeFromModeSelection_diagram_createsDiagramAreaForAddedNode() async throws {
    let inputPort = DiagramModeSelectionCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.addNodeFromModeSelection(mode: .diagram)

    #expect(viewModel.nodes.count == 1)
    #expect(viewModel.pendingEditingNodeID == CanvasNodeID(rawValue: "node-1"))
    let graph = await inputPort.getCurrentGraph()
    let diagramAreas = graph.areasByID.values.filter { $0.editingMode == .diagram }
    #expect(diagramAreas.count == 1)
    #expect(diagramAreas.first?.nodeIDs == [CanvasNodeID(rawValue: "node-1")])
}

@MainActor
@Test("CanvasViewModel: stale diagram mode request still creates area for newly added node")
func test_addNodeFromModeSelection_diagram_staleRequestStillCreatesAreaForAddedNode() async throws {
    let inputPort = StaleDiagramModeSelectionCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    let modeSelectionTask = Task {
        await viewModel.addNodeFromModeSelection(mode: .diagram)
    }
    try await Task.sleep(nanoseconds: 20_000_000)
    await viewModel.apply(commands: [.addNode])
    await inputPort.releaseFirstAddNode()
    await modeSelectionTask.value

    let graph = await inputPort.getCurrentGraph()
    let areaForSecondNodeExists = graph.areasByID.values.contains { area in
        area.editingMode == .diagram && area.nodeIDs == [CanvasNodeID(rawValue: "node-2")]
    }
    #expect(areaForSecondNodeExists)
    #expect(await inputPort.createAreaCallCount() == 1)
}

@MainActor
@Test("CanvasViewModel: diagram mode selection retries createArea when generated area ID collides")
func test_addNodeFromModeSelection_diagram_retriesCreateAreaWhenAreaIDCollides() async throws {
    let inputPort = DiagramAreaCollisionInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.addNodeFromModeSelection(mode: .diagram)

    let graph = await inputPort.getCurrentGraph()
    let addedNodeID = CanvasNodeID(rawValue: "node-2")
    let addedAreaID = try CanvasAreaMembershipService.areaID(containing: addedNodeID, in: graph).get()
    let addedArea = try CanvasAreaMembershipService.area(withID: addedAreaID, in: graph).get()
    #expect(addedArea.editingMode == .diagram)
    #expect(
        await inputPort.createAreaIDs() == [
            CanvasAreaID(rawValue: "diagram-area-1"), CanvasAreaID(rawValue: "diagram-area-2"),
        ])
}

@MainActor
@Test("CanvasViewModel: non-add apply does not publish pending editing node")
func test_apply_nonAddCommand_doesNotSetPendingEditingNodeID() async throws {
    let nodeID = CanvasNodeID(rawValue: "focused")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "before",
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let inputPort = StaticCanvasEditingInputPort(graph: graph)
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.apply(commands: [.setNodeText(nodeID: nodeID, text: "after", nodeHeight: 100)])

    #expect(viewModel.pendingEditingNodeID == nil)
}

@MainActor
@Test("CanvasViewModel: add no-op does not publish pending editing node when displayed nodes are stale")
func test_apply_addNoOp_doesNotSetPendingEditingNodeID_whenDisplayedSnapshotIsStale() async throws {
    let nodeID = CanvasNodeID(rawValue: "focused")
    let graph = CanvasGraph(
        nodesByID: [
            nodeID: CanvasNode(
                id: nodeID,
                kind: .text,
                text: "existing",
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
            )
        ],
        edgesByID: [:],
        focusedNodeID: nodeID
    )
    let inputPort = StaticCanvasEditingInputPort(graph: graph)
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.apply(commands: [.addSiblingNode(position: .below)])

    #expect(viewModel.pendingEditingNodeID == nil)
}

@MainActor
@Test("CanvasViewModel: add-child apply publishes pending editing node")
func test_apply_addChildNode_setsPendingEditingNodeID() async throws {
    let inputPort = AddChildCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.apply(commands: [.addChildNode])

    #expect(viewModel.nodes.count == 1)
    #expect(viewModel.pendingEditingNodeID == CanvasNodeID(rawValue: "child-1"))
}

@MainActor
@Test("CanvasViewModel: add-sibling apply publishes pending editing node")
func test_apply_addSiblingNode_setsPendingEditingNodeID() async throws {
    let inputPort = AddSiblingCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.apply(commands: [.addSiblingNode(position: .below)])

    #expect(viewModel.nodes.count == 1)
    #expect(viewModel.pendingEditingNodeID == CanvasNodeID(rawValue: "sibling-1"))
}

@MainActor
@Test("CanvasViewModel: apply publishes viewport intent from input port")
func test_apply_setsViewportIntent_fromApplyResult() async throws {
    let inputPort = ViewportIntentCanvasEditingInputPort()
    let viewModel = CanvasViewModel(inputPort: inputPort)

    await viewModel.apply(commands: [.moveFocus(.down)])

    #expect(viewModel.viewportIntent == .resetManualPanOffset)
    viewModel.consumeViewportIntent()
    #expect(viewModel.viewportIntent == nil)
}

actor DelayedCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private let getDelayNanoseconds: UInt64

    init(getDelayNanoseconds: UInt64) {
        self.getDelayNanoseconds = getDelayNanoseconds
    }

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        var didAddNode = false
        for command in commands {
            switch command {
            case .addNode:
                let node = CanvasNode(
                    id: CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)"),
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                nextGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph).get()
                nextGraph = CanvasGraph(
                    nodesByID: nextGraph.nodesByID,
                    edgesByID: nextGraph.edgesByID,
                    focusedNodeID: node.id
                )
                didAddNode = true
            case .addChildNode, .addSiblingNode, .moveFocus, .moveNode, .toggleFoldFocusedSubtree,
                .centerFocusedNode, .setNodeText, .convertFocusedAreaMode, .createArea, .assignNodesToArea:
                continue
            case .deleteFocusedNode:
                continue
            }
        }
        graph = nextGraph
        return ApplyResult(newState: nextGraph, didAddNode: didAddNode)
    }

    func getCurrentGraph() async -> CanvasGraph {
        let snapshot = graph
        try? await Task.sleep(nanoseconds: getDelayNanoseconds)
        return snapshot
    }

    func getCurrentResult() async -> ApplyResult {
        let snapshot = await getCurrentGraph()
        return ApplyResult(newState: snapshot)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }
}

actor OverlappingFailureCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private var applyCallCount: Int = 0
    private var firstApplyContinuation: CheckedContinuation<Void, Never>?

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        applyCallCount += 1
        if applyCallCount == 1 {
            await withCheckedContinuation { continuation in
                firstApplyContinuation = continuation
            }
            return try applyCommands(commands, to: graph)
        }

        throw OverlappingFailureCanvasEditingInputPortError.forcedFailure
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func releaseFirstApply() {
        firstApplyContinuation?.resume()
        firstApplyContinuation = nil
    }
}

extension OverlappingFailureCanvasEditingInputPort {
    private func applyCommands(_ commands: [CanvasCommand], to currentGraph: CanvasGraph) throws -> ApplyResult {
        var nextGraph = currentGraph
        var didAddNode = false
        for command in commands {
            switch command {
            case .addNode:
                let node = CanvasNode(
                    id: CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)"),
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                nextGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph).get()
                nextGraph = CanvasGraph(
                    nodesByID: nextGraph.nodesByID,
                    edgesByID: nextGraph.edgesByID,
                    focusedNodeID: node.id
                )
                didAddNode = true
            case .addChildNode, .addSiblingNode, .moveFocus, .moveNode, .toggleFoldFocusedSubtree,
                .centerFocusedNode, .setNodeText, .convertFocusedAreaMode, .createArea, .assignNodesToArea:
                continue
            case .deleteFocusedNode:
                continue
            }
        }
        graph = nextGraph
        return ApplyResult(newState: nextGraph, didAddNode: didAddNode)
    }
}

enum OverlappingFailureCanvasEditingInputPortError: Error {
    case forcedFailure
}

actor ReorderedSuccessCanvasEditingInputPort: CanvasEditingInputPort {
    private var firstApplyContinuation: CheckedContinuation<Void, Never>?

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        if firstApplyContinuation == nil {
            await withCheckedContinuation { continuation in
                firstApplyContinuation = continuation
            }
            return ApplyResult(newState: makeGraph(nodeCount: 1), didAddNode: true)
        }

        return ApplyResult(newState: makeGraph(nodeCount: 2), didAddNode: true)
    }

    func getCurrentGraph() async -> CanvasGraph {
        .empty
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: .empty)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: .empty)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: makeGraph(nodeCount: 2))
    }

    func releaseFirstApply() {
        firstApplyContinuation?.resume()
        firstApplyContinuation = nil
    }
}

actor UndoRedoCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private var undoStack: [CanvasGraph] = []
    private var redoStack: [CanvasGraph] = []

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        guard commands.contains(.addNode) else {
            return makeResult(graph)
        }
        undoStack.append(graph)
        redoStack.removeAll()
        let nodeID = CanvasNodeID(rawValue: "node-\(graph.nodesByID.count + 1)")
        let node = CanvasNode(
            id: nodeID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
        )
        let nextGraph = try CanvasGraphCRUDService.createNode(node, in: graph).get()
        graph = CanvasGraph(
            nodesByID: nextGraph.nodesByID,
            edgesByID: nextGraph.edgesByID,
            focusedNodeID: nodeID
        )
        return makeResult(graph, didAddNode: true)
    }

    func undo() async -> ApplyResult {
        guard let previous = undoStack.popLast() else {
            return makeResult(graph)
        }
        redoStack.append(graph)
        graph = previous
        return makeResult(graph)
    }

    func redo() async -> ApplyResult {
        guard let next = redoStack.popLast() else {
            return makeResult(graph)
        }
        undoStack.append(graph)
        graph = next
        return makeResult(graph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        makeResult(graph)
    }
}

extension UndoRedoCanvasEditingInputPort {
    private func makeResult(_ graph: CanvasGraph, didAddNode: Bool = false) -> ApplyResult {
        ApplyResult(
            newState: graph,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            didAddNode: didAddNode
        )
    }
}

actor ApplyUndoReorderCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private var applyContinuation: CheckedContinuation<Void, Never>?

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        await withCheckedContinuation { continuation in
            applyContinuation = continuation
        }
        let nodeID = CanvasNodeID(rawValue: "node-1")
        graph = CanvasGraph(
            nodesByID: [
                nodeID: CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
            ],
            edgesByID: [:],
            focusedNodeID: nodeID
        )
        return ApplyResult(newState: graph, canUndo: true, canRedo: false, didAddNode: true)
    }

    func undo() async -> ApplyResult {
        graph = .empty
        return ApplyResult(newState: graph, canUndo: false, canRedo: true)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph, canUndo: false, canRedo: false)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph, canUndo: true, canRedo: false)
    }

    func releaseApply() {
        applyContinuation?.resume()
        applyContinuation = nil
    }
}

actor StaticCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph

    init(graph: CanvasGraph) {
        self.graph = graph
    }

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        for command in commands {
            switch command {
            case .setNodeText(let nodeID, let text, _):
                guard let node = nextGraph.nodesByID[nodeID] else {
                    continue
                }
                let updatedNode = CanvasNode(
                    id: node.id,
                    kind: node.kind,
                    text: text,
                    bounds: node.bounds
                )
                nextGraph = CanvasGraph(
                    nodesByID: nextGraph.nodesByID.merging([nodeID: updatedNode], uniquingKeysWith: { _, new in new }),
                    edgesByID: nextGraph.edgesByID,
                    focusedNodeID: nextGraph.focusedNodeID
                )
            case .addNode, .addChildNode, .addSiblingNode, .moveFocus, .moveNode,
                .toggleFoldFocusedSubtree, .centerFocusedNode,
                .deleteFocusedNode, .convertFocusedAreaMode, .createArea, .assignNodesToArea:
                continue
            }
        }
        graph = nextGraph
        return ApplyResult(newState: nextGraph)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }
}

actor AddChildCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        guard commands.contains(.addChildNode) else {
            return ApplyResult(newState: graph)
        }
        let nodeID = CanvasNodeID(rawValue: "child-1")
        let node = CanvasNode(
            id: nodeID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
        )
        let nextGraph = try CanvasGraphCRUDService.createNode(node, in: graph).get()
        graph = CanvasGraph(
            nodesByID: nextGraph.nodesByID,
            edgesByID: nextGraph.edgesByID,
            focusedNodeID: nodeID
        )
        return ApplyResult(newState: graph, didAddNode: true)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }
}

actor AddSiblingCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        guard
            commands.contains(where: { command in
                if case .addSiblingNode = command {
                    return true
                }
                return false
            })
        else {
            return ApplyResult(newState: graph)
        }
        let nodeID = CanvasNodeID(rawValue: "sibling-1")
        let node = CanvasNode(
            id: nodeID,
            kind: .text,
            text: nil,
            bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
        )
        let nextGraph = try CanvasGraphCRUDService.createNode(node, in: graph).get()
        graph = CanvasGraph(
            nodesByID: nextGraph.nodesByID,
            edgesByID: nextGraph.edgesByID,
            focusedNodeID: nodeID
        )
        return ApplyResult(newState: graph, didAddNode: true)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }
}

actor ViewportIntentCanvasEditingInputPort: CanvasEditingInputPort {
    private let focusedNodeID = CanvasNodeID(rawValue: "focused")

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        let graph = CanvasGraph(
            nodesByID: [
                focusedNodeID: CanvasNode(
                    id: focusedNodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
            ],
            edgesByID: [:],
            focusedNodeID: focusedNodeID
        )
        return ApplyResult(
            newState: graph,
            viewportIntent: .resetManualPanOffset
        )
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: .empty)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: .empty)
    }

    func getCurrentGraph() async -> CanvasGraph {
        .empty
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: .empty)
    }
}

actor DiagramModeSelectionCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private var undoStack: [CanvasGraph] = []
    private var redoStack: [CanvasGraph] = []

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        var didAddNode = false

        for command in commands {
            switch command {
            case .addNode:
                undoStack.append(graph)
                redoStack.removeAll()
                let nodeID = CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)")
                let node = CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                let createdGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph).get()
                nextGraph = CanvasGraph(
                    nodesByID: createdGraph.nodesByID,
                    edgesByID: createdGraph.edgesByID,
                    focusedNodeID: nodeID,
                    collapsedRootNodeIDs: createdGraph.collapsedRootNodeIDs,
                    areasByID: createdGraph.areasByID
                )
                didAddNode = true
            case .createArea(let id, let mode, let nodeIDs):
                nextGraph = try CanvasAreaMembershipService.createArea(
                    id: id,
                    mode: mode,
                    nodeIDs: nodeIDs,
                    in: nextGraph
                ).get()
            case .addChildNode, .addSiblingNode, .moveFocus, .moveNode, .toggleFoldFocusedSubtree,
                .centerFocusedNode, .setNodeText,
                .deleteFocusedNode, .convertFocusedAreaMode, .assignNodesToArea:
                continue
            }
        }
        graph = nextGraph
        return ApplyResult(
            newState: graph,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty,
            didAddNode: didAddNode
        )
    }

    func undo() async -> ApplyResult {
        guard let previous = undoStack.popLast() else {
            return ApplyResult(newState: graph)
        }
        redoStack.append(graph)
        graph = previous
        return ApplyResult(newState: graph, canRedo: !redoStack.isEmpty)
    }

    func redo() async -> ApplyResult {
        guard let next = redoStack.popLast() else {
            return ApplyResult(newState: graph)
        }
        undoStack.append(graph)
        graph = next
        return ApplyResult(newState: graph, canUndo: !undoStack.isEmpty)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(
            newState: graph,
            canUndo: !undoStack.isEmpty,
            canRedo: !redoStack.isEmpty
        )
    }
}

actor TreeModeSelectionFromDiagramCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph

    init() {
        let nodeID = CanvasNodeID(rawValue: "node-1")
        let areaID = CanvasAreaID(rawValue: "diagram-area-existing")
        graph = CanvasGraph(
            nodesByID: [
                nodeID: CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
            ],
            edgesByID: [:],
            focusedNodeID: nodeID,
            areasByID: [
                areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .diagram)
            ]
        )
    }

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        var didAddNode = false

        for command in commands {
            switch command {
            case .addNode:
                let nodeID = CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)")
                let node = CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                let createdGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph).get()
                nextGraph = CanvasGraph(
                    nodesByID: createdGraph.nodesByID,
                    edgesByID: createdGraph.edgesByID,
                    focusedNodeID: nodeID,
                    collapsedRootNodeIDs: createdGraph.collapsedRootNodeIDs,
                    areasByID: createdGraph.areasByID
                )
                didAddNode = true
            case .createArea(let id, let mode, let nodeIDs):
                nextGraph = try CanvasAreaMembershipService.createArea(
                    id: id,
                    mode: mode,
                    nodeIDs: nodeIDs,
                    in: nextGraph
                ).get()
            case .addChildNode, .addSiblingNode, .moveFocus, .moveNode, .toggleFoldFocusedSubtree,
                .centerFocusedNode, .setNodeText,
                .deleteFocusedNode, .convertFocusedAreaMode, .assignNodesToArea:
                continue
            }
        }

        graph = nextGraph
        return ApplyResult(newState: graph, didAddNode: didAddNode)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }
}

actor DiagramAreaCollisionInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph
    private var injectedCollision = false
    private var requestedCreateAreaIDs: [CanvasAreaID] = []

    init() {
        let nodeID = CanvasNodeID(rawValue: "node-1")
        let areaID = CanvasAreaID(rawValue: "tree-area-root")
        graph = CanvasGraph(
            nodesByID: [
                nodeID: CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
            ],
            edgesByID: [:],
            focusedNodeID: nodeID,
            areasByID: [
                areaID: CanvasArea(id: areaID, nodeIDs: [nodeID], editingMode: .tree)
            ]
        )
    }

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        var didAddNode = false

        for command in commands {
            switch command {
            case .addNode:
                let nodeID = CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)")
                let node = CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                let createdGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph).get()
                nextGraph = CanvasGraph(
                    nodesByID: createdGraph.nodesByID,
                    edgesByID: createdGraph.edgesByID,
                    focusedNodeID: nodeID,
                    collapsedRootNodeIDs: createdGraph.collapsedRootNodeIDs,
                    areasByID: createdGraph.areasByID
                )
                didAddNode = true
            case .createArea(let id, let mode, let nodeIDs):
                requestedCreateAreaIDs.append(id)
                if !injectedCollision {
                    injectedCollision = true
                    var collisionAreas = nextGraph.areasByID
                    collisionAreas[id] = CanvasArea(id: id, nodeIDs: [], editingMode: mode)
                    graph = CanvasGraph(
                        nodesByID: nextGraph.nodesByID,
                        edgesByID: nextGraph.edgesByID,
                        focusedNodeID: nextGraph.focusedNodeID,
                        collapsedRootNodeIDs: nextGraph.collapsedRootNodeIDs,
                        areasByID: collisionAreas
                    )
                    throw CanvasAreaPolicyError.areaAlreadyExists(id)
                }

                nextGraph = try CanvasAreaMembershipService.createArea(
                    id: id,
                    mode: mode,
                    nodeIDs: nodeIDs,
                    in: nextGraph
                ).get()
            case .addChildNode, .addSiblingNode, .moveFocus, .moveNode, .toggleFoldFocusedSubtree,
                .centerFocusedNode, .setNodeText,
                .deleteFocusedNode, .convertFocusedAreaMode, .assignNodesToArea:
                continue
            }
        }

        graph = nextGraph
        return ApplyResult(newState: graph, didAddNode: didAddNode)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func createAreaIDs() -> [CanvasAreaID] {
        requestedCreateAreaIDs
    }
}

actor StaleDiagramModeSelectionCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private var addNodeCallCount: Int = 0
    private var createAreaCount: Int = 0
    private var firstAddContinuation: CheckedContinuation<Void, Never>?

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        var didAddNode = false

        for command in commands {
            switch command {
            case .addNode:
                addNodeCallCount += 1
                if addNodeCallCount == 1 {
                    await withCheckedContinuation { continuation in
                        firstAddContinuation = continuation
                    }
                    nextGraph = graph
                }
                let nodeID = CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)")
                let node = CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                let createdGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph).get()
                nextGraph = CanvasGraph(
                    nodesByID: createdGraph.nodesByID,
                    edgesByID: createdGraph.edgesByID,
                    focusedNodeID: nodeID,
                    collapsedRootNodeIDs: createdGraph.collapsedRootNodeIDs,
                    areasByID: createdGraph.areasByID
                )
                didAddNode = true
            case .createArea(let id, let mode, let nodeIDs):
                createAreaCount += 1
                nextGraph = try CanvasAreaMembershipService.createArea(
                    id: id,
                    mode: mode,
                    nodeIDs: nodeIDs,
                    in: nextGraph
                ).get()
            case .addChildNode, .addSiblingNode, .moveFocus, .moveNode, .toggleFoldFocusedSubtree,
                .centerFocusedNode, .setNodeText,
                .deleteFocusedNode, .convertFocusedAreaMode, .assignNodesToArea:
                continue
            }
        }

        graph = nextGraph
        return ApplyResult(newState: graph, didAddNode: didAddNode)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func releaseFirstAddNode() {
        firstAddContinuation?.resume()
        firstAddContinuation = nil
    }

    func createAreaCallCount() -> Int {
        createAreaCount
    }
}

extension ReorderedSuccessCanvasEditingInputPort {
    private func makeGraph(nodeCount: Int) -> CanvasGraph {
        var nodesByID: [CanvasNodeID: CanvasNode] = [:]
        for index in 1...nodeCount {
            let nodeID = CanvasNodeID(rawValue: "node-\(index)")
            nodesByID[nodeID] = CanvasNode(
                id: nodeID,
                kind: .text,
                text: nil,
                bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
            )
        }
        let focusedNodeID = CanvasNodeID(rawValue: "node-\(nodeCount)")
        return CanvasGraph(nodesByID: nodesByID, edgesByID: [:], focusedNodeID: focusedNodeID)
    }
}

actor EmptyBootstrapCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        for command in commands {
            switch command {
            case .addNode:
                let nodeID = CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)")
                let node = CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                nextGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph).get()
                nextGraph = CanvasGraph(
                    nodesByID: nextGraph.nodesByID,
                    edgesByID: nextGraph.edgesByID,
                    focusedNodeID: nodeID
                )
            case .addChildNode, .addSiblingNode, .moveFocus, .moveNode, .toggleFoldFocusedSubtree,
                .centerFocusedNode, .setNodeText,
                .deleteFocusedNode, .convertFocusedAreaMode, .createArea, .assignNodesToArea:
                continue
            }
        }
        graph = nextGraph
        return ApplyResult(newState: nextGraph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }
}

actor OverlappingInitialNodeCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private var getCurrentResultCallCount: Int = 0

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        for command in commands {
            switch command {
            case .addNode:
                try? await Task.sleep(nanoseconds: 300_000_000)
                let nodeID = CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)")
                let node = CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                nextGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph).get()
                nextGraph = CanvasGraph(
                    nodesByID: nextGraph.nodesByID,
                    edgesByID: nextGraph.edgesByID,
                    focusedNodeID: nodeID
                )
            case .addChildNode, .addSiblingNode, .moveFocus, .moveNode, .toggleFoldFocusedSubtree,
                .centerFocusedNode, .setNodeText,
                .deleteFocusedNode, .convertFocusedAreaMode, .createArea, .assignNodesToArea:
                continue
            }
        }
        graph = nextGraph
        return ApplyResult(newState: nextGraph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        getCurrentResultCallCount += 1
        if getCurrentResultCallCount == 1 {
            let snapshot = graph
            try? await Task.sleep(nanoseconds: 200_000_000)
            return ApplyResult(newState: snapshot)
        }
        return ApplyResult(newState: graph)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func nodeCount() -> Int {
        graph.nodesByID.count
    }
}

actor StaleBootstrapApplyCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private var applyCallCount: Int = 0
    private var firstApplyContinuation: CheckedContinuation<Void, Never>?

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        applyCallCount += 1
        if applyCallCount == 1 {
            await withCheckedContinuation { continuation in
                firstApplyContinuation = continuation
            }
            graph = makeSingleNodeGraph()
            return ApplyResult(newState: graph)
        }

        return ApplyResult(newState: .empty)
    }

    func getCurrentGraph() async -> CanvasGraph {
        graph
    }

    func getCurrentResult() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func undo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func redo() async -> ApplyResult {
        ApplyResult(newState: graph)
    }

    func releaseFirstApply() {
        firstApplyContinuation?.resume()
        firstApplyContinuation = nil
    }
}

extension StaleBootstrapApplyCanvasEditingInputPort {
    private func makeSingleNodeGraph() -> CanvasGraph {
        let nodeID = CanvasNodeID(rawValue: "node-1")
        return CanvasGraph(
            nodesByID: [
                nodeID: CanvasNode(
                    id: nodeID,
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
            ],
            edgesByID: [:],
            focusedNodeID: nodeID
        )
    }
}
