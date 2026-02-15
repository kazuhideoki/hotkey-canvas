// Background: The canvas needs a single view that coordinates rendering, hotkeys, and inline text editing.
// Responsibility: Render nodes/edges and orchestrate transitions between hotkey mode and node-editing mode.
import AppKit
import Combine
import Domain
import Foundation
import SwiftUI

/// SwiftUI canvas that displays graph nodes and handles keyboard-first editing interactions.
public struct CanvasView: View {
    private static let minimumCanvasWidth: Double = 900
    private static let minimumCanvasHeight: Double = 600
    private static let canvasMargin: Double = 120

    @StateObject private var viewModel: CanvasViewModel
    @State private var editingContext: NodeEditingContext?
    /// Monotonic token used to ignore stale async editing-start tasks.
    @State private var pendingEditingRequestID: UInt64 = 0
    private let hotkeyTranslator: CanvasHotkeyTranslator
    private let editingStartResolver = NodeEditingStartResolver()
    private let nodeTextHeightMeasurer = NodeTextHeightMeasurer()

    public init(
        viewModel: CanvasViewModel,
        hotkeyTranslator: CanvasHotkeyTranslator = CanvasHotkeyTranslator()
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.hotkeyTranslator = hotkeyTranslator
    }

    public var body: some View {
        let displayNodes = viewModel.nodes.map(displayNodeForCurrentEditingState)
        let nodesByID = Dictionary(uniqueKeysWithValues: displayNodes.map { ($0.id, $0) })
        let contentBounds = CanvasContentBoundsCalculator.calculate(
            nodes: displayNodes,
            minimumWidth: Self.minimumCanvasWidth,
            minimumHeight: Self.minimumCanvasHeight,
            margin: Self.canvasMargin
        )
        let horizontalOffset = -contentBounds.minX
        let verticalOffset = -contentBounds.minY

        return ScrollViewReader { scrollProxy in
            ZStack(alignment: .topLeading) {
                Color(nsColor: .textBackgroundColor)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                ScrollView([.horizontal, .vertical]) {
                    ZStack(alignment: .topLeading) {
                        ForEach(viewModel.edges, id: \.id) { edge in
                            if let fromNode = nodesByID[edge.fromNodeID], let toNode = nodesByID[edge.toNodeID] {
                                Path { path in
                                    path.move(
                                        to: centerPoint(
                                            for: fromNode,
                                            horizontalOffset: horizontalOffset,
                                            verticalOffset: verticalOffset
                                        )
                                    )
                                    path.addLine(
                                        to: centerPoint(
                                            for: toNode,
                                            horizontalOffset: horizontalOffset,
                                            verticalOffset: verticalOffset
                                        )
                                    )
                                }
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1.5)
                            }
                        }

                        ForEach(displayNodes, id: \.id) { node in
                            let isFocused = viewModel.focusedNodeID == node.id
                            let isEditing = editingContext?.nodeID == node.id
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            isEditing
                                                ? Color(nsColor: .systemPink)
                                                : (isFocused ? Color.accentColor : Color(nsColor: .separatorColor)),
                                            lineWidth: (isEditing || isFocused) ? 2 : 1
                                        )
                                )
                                .overlay(alignment: .topLeading) {
                                    if editingContext?.nodeID == node.id {
                                        NodeTextEditor(
                                            text: editingTextBinding(for: node.id),
                                            selectAllOnFirstFocus: false,
                                            initialCursorPlacement: editingContext?.initialCursorPlacement ?? .end,
                                            onMeasuredHeightChange: { measuredHeight in
                                                updateEditingNodeHeight(for: node.id, measuredHeight: measuredHeight)
                                            },
                                            onCommit: {
                                                commitNodeEditing()
                                            },
                                            onCancel: {
                                                cancelNodeEditing()
                                            }
                                        )
                                        .padding(6)
                                    } else {
                                        Text(node.text ?? "")
                                            .font(.system(size: NodeTextStyle.fontSize, weight: .medium))
                                            .padding(12)
                                    }
                                }
                                .frame(
                                    width: CGFloat(node.bounds.width),
                                    height: CGFloat(node.bounds.height),
                                    alignment: .topLeading
                                )
                                .position(
                                    x: CGFloat(node.bounds.x + horizontalOffset + (node.bounds.width / 2)),
                                    y: CGFloat(node.bounds.y + verticalOffset + (node.bounds.height / 2))
                                )
                                .id(node.id)
                        }
                    }
                    .frame(
                        width: CGFloat(contentBounds.width),
                        height: CGFloat(contentBounds.height),
                        alignment: .topLeading
                    )
                }

                CanvasHotkeyCaptureView(isEnabled: editingContext == nil) { event in
                    if let historyAction = hotkeyTranslator.historyAction(event) {
                        Task {
                            switch historyAction {
                            case .undo:
                                await viewModel.undo()
                            case .redo:
                                await viewModel.redo()
                            }
                        }
                        return true
                    }
                    let commands = hotkeyTranslator.translate(event)
                    guard !commands.isEmpty else {
                        return handleTypingInputStart(event, nodesByID: nodesByID)
                    }
                    // Returning true tells the capture view to stop responder-chain propagation.
                    Task { await viewModel.apply(commands: commands) }
                    return true
                }
                .frame(width: 1, height: 1)
                // Keep key capture active without intercepting canvas rendering.
                .allowsHitTesting(false)
            }
            .frame(
                minWidth: Self.minimumCanvasWidth,
                minHeight: Self.minimumCanvasHeight,
                alignment: .topLeading
            )
            .task {
                let initialEditingNodeID = await viewModel.onAppear()
                startInitialNodeEditingIfNeeded(nodeID: initialEditingNodeID)
                focusCurrentNode(with: scrollProxy)
            }
            .onChange(of: viewModel.focusedNodeID) { _ in
                focusCurrentNode(with: scrollProxy)
            }
        }
        .onReceive(viewModel.$pendingEditingNodeID) { pendingNodeID in
            pendingEditingRequestID &+= 1
            guard let nodeID = pendingNodeID else {
                return
            }
            let requestID = pendingEditingRequestID
            Task { @MainActor in
                let maxLookupAttempts = 4
                for attempt in 0..<maxLookupAttempts {
                    guard pendingEditingRequestID == requestID else {
                        return
                    }
                    guard viewModel.pendingEditingNodeID == nodeID else {
                        return
                    }
                    if let node = viewModel.nodes.first(where: { $0.id == nodeID }) {
                        let measuredHeight = measuredNodeHeight(
                            text: node.text ?? "",
                            nodeWidth: node.bounds.width
                        )
                        editingContext = NodeEditingContext(
                            nodeID: nodeID,
                            text: node.text ?? "",
                            nodeWidth: node.bounds.width,
                            nodeHeight: measuredHeight,
                            initialCursorPlacement: .end
                        )
                        guard pendingEditingRequestID == requestID else {
                            return
                        }
                        guard viewModel.pendingEditingNodeID == nodeID else {
                            return
                        }
                        viewModel.consumePendingEditingNodeID()
                        return
                    }
                    guard attempt < (maxLookupAttempts - 1) else {
                        break
                    }
                    // Wait for subsequent UI updates when apply completion and rendering race.
                    await Task.yield()
                }
                guard pendingEditingRequestID == requestID else {
                    return
                }
                guard viewModel.pendingEditingNodeID == nodeID else {
                    return
                }
                viewModel.consumePendingEditingNodeID()
            }
        }
    }
}

extension CanvasView {
    private func displayNodeForCurrentEditingState(_ node: CanvasNode) -> CanvasNode {
        guard let editingContext, editingContext.nodeID == node.id else {
            return node
        }
        let requiredHeight =
            if editingContext.nodeHeight.isFinite {
                max(editingContext.nodeHeight, 1)
            } else {
                node.bounds.height
            }
        guard requiredHeight != node.bounds.height else {
            return node
        }
        let resizedBounds = CanvasBounds(
            x: node.bounds.x,
            y: node.bounds.y,
            width: node.bounds.width,
            height: requiredHeight
        )
        return CanvasNode(
            id: node.id,
            kind: node.kind,
            text: node.text,
            bounds: resizedBounds,
            metadata: node.metadata
        )
    }

    private func centerPoint(
        for node: CanvasNode,
        horizontalOffset: Double,
        verticalOffset: Double
    ) -> CGPoint {
        CGPoint(
            x: node.bounds.x + (node.bounds.width / 2) + horizontalOffset,
            y: node.bounds.y + (node.bounds.height / 2) + verticalOffset
        )
    }

    private func focusCurrentNode(with proxy: ScrollViewProxy) {
        guard let focusedNodeID = viewModel.focusedNodeID else {
            return
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            proxy.scrollTo(focusedNodeID, anchor: .center)
        }
    }

    private func editingTextBinding(for nodeID: CanvasNodeID) -> Binding<String> {
        Binding(
            get: {
                guard editingContext?.nodeID == nodeID else {
                    return ""
                }
                return editingContext?.text ?? ""
            },
            set: { updatedText in
                guard var context = editingContext, context.nodeID == nodeID else {
                    return
                }
                context.text = updatedText
                editingContext = context
            }
        )
    }

    private func handleTypingInputStart(
        _ event: NSEvent,
        nodesByID: [CanvasNodeID: CanvasNode]
    ) -> Bool {
        guard
            let context = editingStartResolver.resolve(
                from: event,
                focusedNodeID: viewModel.focusedNodeID,
                nodesByID: nodesByID
            )
        else {
            return false
        }
        guard let node = nodesByID[context.nodeID] else {
            return false
        }

        let measuredHeight = measuredNodeHeight(text: context.text, nodeWidth: node.bounds.width)
        editingContext = NodeEditingContext(
            nodeID: context.nodeID,
            text: context.text,
            nodeWidth: node.bounds.width,
            nodeHeight: measuredHeight,
            initialCursorPlacement: context.initialCursorPlacement
        )
        return true
    }

    private func commitNodeEditingIfNeeded() {
        guard let context = editingContext else {
            return
        }
        commitNodeEditing(context)
    }

    private func commitNodeEditing() {
        commitNodeEditingIfNeeded()
    }

    private func commitNodeEditing(_ context: NodeEditingContext) {
        editingContext = nil
        Task {
            await viewModel.commitNodeText(
                nodeID: context.nodeID,
                text: context.text,
                nodeHeight: context.nodeHeight
            )
        }
    }

    private func cancelNodeEditing() {
        editingContext = nil
    }

    private func updateEditingNodeHeight(for nodeID: CanvasNodeID, measuredHeight: CGFloat) {
        guard var context = editingContext, context.nodeID == nodeID else {
            return
        }
        let roundedHeight = Double(ceil(measuredHeight))
        guard roundedHeight.isFinite, roundedHeight > 0 else {
            return
        }
        guard context.nodeHeight != roundedHeight else {
            return
        }
        context.nodeHeight = roundedHeight
        editingContext = context
    }

    private func measuredNodeHeight(text: String, nodeWidth: Double) -> Double {
        Double(nodeTextHeightMeasurer.measure(text: text, nodeWidth: CGFloat(nodeWidth)))
    }

    private func startInitialNodeEditingIfNeeded(nodeID: CanvasNodeID?) {
        guard editingContext == nil, let nodeID else {
            return
        }
        guard let node = viewModel.nodes.first(where: { $0.id == nodeID }) else {
            return
        }
        let measuredHeight = measuredNodeHeight(text: node.text ?? "", nodeWidth: node.bounds.width)
        editingContext = NodeEditingContext(
            nodeID: nodeID,
            text: node.text ?? "",
            nodeWidth: node.bounds.width,
            nodeHeight: measuredHeight,
            initialCursorPlacement: .end
        )
    }
}

private struct NodeEditingContext: Equatable {
    let nodeID: CanvasNodeID
    var text: String
    let nodeWidth: Double
    var nodeHeight: Double
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
}
