// Background: The canvas needs a single view that coordinates rendering, hotkeys, and inline text editing.
// Responsibility: Render nodes/edges and orchestrate transitions between hotkey mode and node-editing mode.
import AppKit
import Combine
import Domain
import SwiftUI

/// SwiftUI canvas that displays graph nodes and handles keyboard-first editing interactions.
public struct CanvasView: View {
    static let minimumCanvasWidth: Double = 900
    static let minimumCanvasHeight: Double = 600

    @StateObject var viewModel: CanvasViewModel
    @State var editingContext: NodeEditingContext?
    /// Monotonic token used to ignore stale async editing-start tasks.
    @State private var pendingEditingRequestID: UInt64 = 0
    private let hotkeyTranslator: CanvasHotkeyTranslator
    let editingStartResolver = NodeEditingStartResolver()
    let nodeTextHeightMeasurer = NodeTextHeightMeasurer()

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
        return GeometryReader { geometryProxy in
            let viewportSize = CGSize(
                width: max(geometryProxy.size.width, Self.minimumCanvasWidth),
                height: max(geometryProxy.size.height, Self.minimumCanvasHeight)
            )
            let cameraOffset = cameraOffset(for: displayNodes, viewportSize: viewportSize)
            ZStack(alignment: .topLeading) {
                Color(nsColor: .textBackgroundColor)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())

                ZStack(alignment: .topLeading) {
                    ForEach(viewModel.edges, id: \.id) { edge in
                        if let fromNode = nodesByID[edge.fromNodeID], let toNode = nodesByID[edge.toNodeID] {
                            Path { path in
                                path.move(to: centerPoint(for: fromNode))
                                path.addLine(to: centerPoint(for: toNode))
                            }
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1.5)
                        }
                    }

<<<<<<< HEAD
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
                                        .font(.system(size: 14, weight: .medium))
                                        .padding(12)
=======
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
>>>>>>> main
                                }
                            }
                            .frame(
                                width: CGFloat(node.bounds.width),
                                height: CGFloat(node.bounds.height),
                                alignment: .topLeading
                            )
                            .position(
                                x: CGFloat(node.bounds.x + (node.bounds.width / 2)),
                                y: CGFloat(node.bounds.y + (node.bounds.height / 2))
                            )
                    }
                }
                .offset(x: cameraOffset.width, y: cameraOffset.height)

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
