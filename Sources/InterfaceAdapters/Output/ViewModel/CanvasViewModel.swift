import Application
import Combine
import Domain

@MainActor
public final class CanvasViewModel: ObservableObject {
    @Published public private(set) var nodes: [CanvasNode] = []
    @Published public private(set) var edges: [CanvasEdge] = []
    @Published public private(set) var focusedNodeID: CanvasNodeID?
    @Published public private(set) var collapsedRootNodeIDs: Set<CanvasNodeID> = []
    @Published public private(set) var pendingEditingNodeID: CanvasNodeID?
    @Published public private(set) var viewportIntent: CanvasViewportIntent?
    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false

    private let inputPort: any CanvasEditingInputPort
    private var nextRequestID: UInt64 = 0
    private var latestDisplayedRequestID: UInt64 = 0

    public init(inputPort: any CanvasEditingInputPort) {
        self.inputPort = inputPort
    }

    @discardableResult
    public func onAppear() async -> CanvasNodeID? {
        let requestIDAtStart = latestDisplayedRequestID
        let result = await inputPort.getCurrentResult()
        // Ignore stale snapshot when a newer apply() result has already been displayed.
        guard requestIDAtStart == latestDisplayedRequestID else {
            return nil
        }

        guard result.newState.nodesByID.isEmpty else {
            updateDisplay(with: result)
            return nil
        }

        let requestID = consumeNextRequestID()
        // Re-check current graph right before bootstrapping to avoid double add
        // when another apply() was already started while the first snapshot was loading.
        let latestResult = await inputPort.getCurrentResult()
        guard shouldDisplayResult(for: requestID) else {
            return nil
        }
        guard latestResult.newState.nodesByID.isEmpty else {
            updateDisplay(with: latestResult)
            markDisplayed(requestID)
            return nil
        }

        do {
            let initialNodeResult = try await inputPort.apply(commands: [.addNode])
            guard shouldDisplayResult(for: requestID) else {
                await refreshDisplayFromCurrentResult()
                return nil
            }
            updateDisplay(with: initialNodeResult)
            markDisplayed(requestID)
            return initialNodeResult.newState.focusedNodeID
        } catch {
            // Keep current display state when initial node creation fails.
            return nil
        }
    }

    public func apply(commands: [CanvasCommand]) async {
        guard !commands.isEmpty else {
            return
        }

        let requestID = consumeNextRequestID()
        do {
            let result = try await inputPort.apply(commands: commands)
            // Only display results newer than the currently displayed request.
            guard shouldDisplayResult(for: requestID) else {
                return
            }
            let shouldStartEditing = shouldStartEditingAfterApply(commands: commands, result: result)
            updateDisplay(with: result)
            pendingEditingNodeID = shouldStartEditing ? result.newState.focusedNodeID : nil
            markDisplayed(requestID)
        } catch {
            // Keep current display state when command application fails.
        }
    }

    public func undo() async {
        let requestID = consumeNextRequestID()
        let result = await inputPort.undo()
        guard shouldDisplayResult(for: requestID) else {
            return
        }
        updateDisplay(with: result)
        pendingEditingNodeID = nil
        markDisplayed(requestID)
    }

    public func redo() async {
        let requestID = consumeNextRequestID()
        let result = await inputPort.redo()
        guard shouldDisplayResult(for: requestID) else {
            return
        }
        updateDisplay(with: result)
        pendingEditingNodeID = nil
        markDisplayed(requestID)
    }

    public func commitNodeText(nodeID: CanvasNodeID, text: String, nodeHeight: Double) async {
        await apply(commands: [.setNodeText(nodeID: nodeID, text: text, nodeHeight: nodeHeight)])
    }

    public func consumePendingEditingNodeID() {
        pendingEditingNodeID = nil
    }

    public func consumeViewportIntent() {
        viewportIntent = nil
    }
}

extension CanvasViewModel {
    // Keep one global request timeline for apply/undo/redo.
    // This prevents older async completions from overwriting a newer user action.
    private func consumeNextRequestID() -> UInt64 {
        nextRequestID &+= 1
        return nextRequestID
    }

    private func shouldDisplayResult(for requestID: UInt64) -> Bool {
        requestID > latestDisplayedRequestID
    }

    private func markDisplayed(_ requestID: UInt64) {
        latestDisplayedRequestID = requestID
    }

    private func shouldStartEditingAfterApply(
        commands: [CanvasCommand],
        result: ApplyResult
    ) -> Bool {
        guard commands.contains(where: isInlineEditingStartCommand) else {
            return false
        }
        guard result.didAddNode else {
            return false
        }
        return result.newState.focusedNodeID != nil
    }

    private func isInlineEditingStartCommand(_ command: CanvasCommand) -> Bool {
        switch command {
        case .addNode, .addChildNode, .addSiblingNode:
            return true
        case .moveFocus, .moveNode, .toggleFoldFocusedSubtree, .centerFocusedNode, .deleteFocusedNode,
            .setNodeText, .createArea, .assignNodesToArea:
            return false
        }
    }

    private func updateDisplay(with result: ApplyResult) {
        let visibleGraph = CanvasFoldedSubtreeVisibilityService.visibleGraph(from: result.newState)
        nodes = sortedNodes(in: visibleGraph)
        edges = sortedEdges(in: visibleGraph)
        focusedNodeID = visibleGraph.focusedNodeID
        collapsedRootNodeIDs = CanvasFoldedSubtreeVisibilityService.normalizedCollapsedRootNodeIDs(
            in: result.newState
        )
        viewportIntent = result.viewportIntent
        canUndo = result.canUndo
        canRedo = result.canRedo
    }

    private func refreshDisplayFromCurrentResult() async {
        let latestResult = await inputPort.getCurrentResult()
        updateDisplay(with: latestResult)
    }

    private func sortedNodes(in graph: CanvasGraph) -> [CanvasNode] {
        graph.nodesByID.values.sorted {
            if $0.bounds.y == $1.bounds.y {
                return $0.bounds.x < $1.bounds.x
            }
            return $0.bounds.y < $1.bounds.y
        }
    }

    private func sortedEdges(in graph: CanvasGraph) -> [CanvasEdge] {
        graph.edgesByID.values.sorted { lhs, rhs in
            if lhs.fromNodeID.rawValue != rhs.fromNodeID.rawValue {
                return lhs.fromNodeID.rawValue < rhs.fromNodeID.rawValue
            }
            if lhs.toNodeID.rawValue != rhs.toNodeID.rawValue {
                return lhs.toNodeID.rawValue < rhs.toNodeID.rawValue
            }
            return lhs.id.rawValue < rhs.id.rawValue
        }
    }
}
