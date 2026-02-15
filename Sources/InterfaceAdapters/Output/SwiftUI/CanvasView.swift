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
    private static let nodeTextLineHeight: Double = 20
    private static let nodeTextVerticalPadding: Double = 24
    private static let minimumTextNodeHeight: Double = 120

    @StateObject private var viewModel: CanvasViewModel
    @State private var editingContext: NodeEditingContext?
    /// Monotonic token used to ignore stale async editing-start tasks.
    @State private var pendingEditingRequestID: UInt64 = 0
    private let hotkeyTranslator: CanvasHotkeyTranslator
    private let editingStartResolver = NodeEditingStartResolver()

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
                                            .font(.system(size: 14, weight: .medium))
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
                await viewModel.onAppear()
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
                        editingContext = NodeEditingContext(
                            nodeID: nodeID,
                            text: node.text ?? "",
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
        let requiredHeight = requiredEditingHeight(
            for: editingContext.text,
            baselineHeight: baselineHeight(for: node.bounds)
        )
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

    private func baselineHeight(for bounds: CanvasBounds) -> Double {
        min(bounds.height, Self.minimumTextNodeHeight)
    }

    private func requiredEditingHeight(for text: String, baselineHeight: Double) -> Double {
        let normalizedText =
            text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lineCount =
            normalizedText
            .split(separator: "\n", omittingEmptySubsequences: false)
            .count
        let contentHeight = (Double(max(1, lineCount)) * Self.nodeTextLineHeight) + Self.nodeTextVerticalPadding
        return max(baselineHeight, contentHeight)
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
                guard editingContext?.nodeID == nodeID else {
                    return
                }
                editingContext?.text = updatedText
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
        editingContext = NodeEditingContext(
            nodeID: context.nodeID,
            text: context.text,
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
            await viewModel.commitNodeText(nodeID: context.nodeID, text: context.text)
        }
    }

    private func cancelNodeEditing() {
        editingContext = nil
    }
}

private struct NodeEditingContext: Equatable {
    let nodeID: CanvasNodeID
    var text: String
    let initialCursorPlacement: NodeTextEditorInitialCursorPlacement
}
