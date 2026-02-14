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
    await onAppearTask.value

    #expect(viewModel.nodes.count == 1)
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

actor DelayedCanvasEditingInputPort: CanvasEditingInputPort {
    private var graph: CanvasGraph = .empty
    private let getDelayNanoseconds: UInt64

    init(getDelayNanoseconds: UInt64) {
        self.getDelayNanoseconds = getDelayNanoseconds
    }

    func apply(commands: [CanvasCommand]) async throws -> ApplyResult {
        var nextGraph = graph
        for command in commands {
            switch command {
            case .addNode:
                let node = CanvasNode(
                    id: CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)"),
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                nextGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph)
                nextGraph = CanvasGraph(
                    nodesByID: nextGraph.nodesByID,
                    edgesByID: nextGraph.edgesByID,
                    focusedNodeID: node.id
                )
            case .moveFocus:
                continue
            case .deleteFocusedNode:
                continue
            }
        }
        graph = nextGraph
        return ApplyResult(newState: nextGraph)
    }

    func getCurrentGraph() async -> CanvasGraph {
        let snapshot = graph
        try? await Task.sleep(nanoseconds: getDelayNanoseconds)
        return snapshot
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

    func releaseFirstApply() {
        firstApplyContinuation?.resume()
        firstApplyContinuation = nil
    }
}

extension OverlappingFailureCanvasEditingInputPort {
    private func applyCommands(_ commands: [CanvasCommand], to currentGraph: CanvasGraph) throws -> ApplyResult {
        var nextGraph = currentGraph
        for command in commands {
            switch command {
            case .addNode:
                let node = CanvasNode(
                    id: CanvasNodeID(rawValue: "node-\(nextGraph.nodesByID.count + 1)"),
                    kind: .text,
                    text: nil,
                    bounds: CanvasBounds(x: 0, y: 0, width: 200, height: 100)
                )
                nextGraph = try CanvasGraphCRUDService.createNode(node, in: nextGraph)
                nextGraph = CanvasGraph(
                    nodesByID: nextGraph.nodesByID,
                    edgesByID: nextGraph.edgesByID,
                    focusedNodeID: node.id
                )
            case .moveFocus:
                continue
            case .deleteFocusedNode:
                continue
            }
        }
        graph = nextGraph
        return ApplyResult(newState: nextGraph)
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
            return ApplyResult(newState: makeGraph(nodeCount: 1))
        }

        return ApplyResult(newState: makeGraph(nodeCount: 2))
    }

    func getCurrentGraph() async -> CanvasGraph {
        .empty
    }

    func releaseFirstApply() {
        firstApplyContinuation?.resume()
        firstApplyContinuation = nil
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
