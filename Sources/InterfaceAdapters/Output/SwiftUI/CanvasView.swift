// Background: The canvas needs a single view that coordinates rendering, hotkeys, and inline text editing.
// Responsibility: Render nodes/edges and orchestrate transitions between hotkey mode and node-editing mode.
import AppKit
import Combine
import Domain
import SwiftUI

// swiftlint:disable type_body_length
/// SwiftUI canvas that displays graph nodes and handles keyboard-first editing interactions.
public struct CanvasView: View {
    static let minimumCanvasWidth: Double = 900
    static let minimumCanvasHeight: Double = 600
    @StateObject var viewModel: CanvasViewModel
    @State var editingContext: NodeEditingContext?
    @State var commandPaletteQuery: String = ""
    @State var isCommandPalettePresented = false
    @State var selectedCommandPaletteIndex: Int = 0
    @State private var previousSelectedCommandPaletteIndex: Int = 0
    @State var hasInitializedCameraAnchor = false
    @State var cameraAnchorPoint: CGPoint = .zero
    @State var manualPanOffset: CGSize = .zero
    @State var zoomScale: Double = 1.0
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
            let autoCenterOffset = cameraOffset(viewportSize: viewportSize)
            let scaledAutoCenterOffset = CGSize(
                width: autoCenterOffset.width * zoomScale,
                height: autoCenterOffset.height * zoomScale
            )
            let cameraOffset = CanvasViewportPanPolicy.combinedOffset(
                autoCenterOffset: scaledAutoCenterOffset,
                manualPanOffset: manualPanOffset,
                activeDragOffset: .zero
            )
            let renderedNodes = displayNodes.map {
                renderedNode($0, viewportSize: viewportSize, effectiveOffset: cameraOffset)
            }
            let renderedNodesByID = Dictionary(uniqueKeysWithValues: renderedNodes.map { ($0.id, $0) })
            let branchXByParentAndDirection = CanvasEdgeRouting.branchXByParentAndDirection(
                edges: viewModel.edges,
                nodesByID: nodesByID
            )
            let commandPaletteItems = filteredCommandPaletteItems()
            ZStack(alignment: .topLeading) {
                Color(nsColor: .textBackgroundColor)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                if isCommandPalettePresented {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Command Palette")
                            .font(.headline)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                        CommandPaletteTextField(
                            text: $commandPaletteQuery,
                            onSubmit: {
                                executeSelectedCommandIfNeeded()
                            },
                            onCancel: {
                                closeCommandPalette()
                            },
                            onMoveSelectionUp: {
                                movePaletteSelection(offset: -1)
                            },
                            onMoveSelectionDown: {
                                movePaletteSelection(offset: 1)
                            }
                        )
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .textBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        Rectangle()
                            .fill(Color(nsColor: .separatorColor))
                            .frame(height: 1)
                            .padding(.top, 10)
                        ScrollViewReader { scrollProxy in
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(Array(commandPaletteItems.enumerated()), id: \.element.id) { index, item in
                                        HStack {
                                            Text(item.title)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                            Text(item.shortcutLabel)
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: 170, alignment: .trailing)
                                        }
                                        .font(.system(size: 13, weight: .medium))
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .background(
                                            index == selectedCommandPaletteIndex
                                                ? Color.accentColor.opacity(0.2) : .clear
                                        )
                                        .id(item.id)
                                        .onTapGesture {
                                            selectedCommandPaletteIndex = index
                                            executeSelectedCommand(item)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 280)
                            .onAppear {
                                guard isCommandPalettePresented,
                                    let firstItem = commandPaletteItems.first
                                else {
                                    return
                                }
                                scrollProxy.scrollTo(firstItem.id, anchor: .top)
                            }
                            .onChange(of: selectedCommandPaletteIndex) { selectedIndex in
                                guard commandPaletteItems.indices.contains(selectedIndex) else {
                                    return
                                }
                                let isMovingDown = selectedIndex > previousSelectedCommandPaletteIndex
                                previousSelectedCommandPaletteIndex = selectedIndex
                                scrollProxy.scrollTo(
                                    commandPaletteItems[selectedIndex].id,
                                    anchor: isMovingDown ? .bottom : .top
                                )
                            }
                            .onChange(of: commandPaletteQuery) { _ in
                                guard isCommandPalettePresented else {
                                    return
                                }
                                guard let firstItem = commandPaletteItems.first else {
                                    return
                                }
                                scrollProxy.scrollTo(firstItem.id, anchor: .top)
                            }
                        }
                    }
                    .frame(width: 520)
                    .background(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .animation(.easeInOut(duration: 0.15), value: commandPaletteItems.count)
                    .zIndex(10)
                }
                ZStack(alignment: .topLeading) {
                    ForEach(viewModel.edges, id: \.id) { edge in
                        if let path = CanvasEdgeRouting.path(
                            for: edge,
                            nodesByID: nodesByID,
                            branchXByParentAndDirection: branchXByParentAndDirection
                        ) {
                            path
                                .applying(
                                    CanvasViewportTransform.affineTransform(
                                        viewportSize: viewportSize,
                                        zoomScale: zoomScale,
                                        effectiveOffset: cameraOffset
                                    )
                                )
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 2.25)
                        }
                    }
                    ForEach(displayNodes, id: \.id) { node in
                        if let renderedNode = renderedNodesByID[node.id] {
                            let isFocused = viewModel.focusedNodeID == node.id
                            let isCollapsedRoot = viewModel.collapsedRootNodeIDs.contains(node.id)
                            let isEditing = editingContext?.nodeID == node.id
                            RoundedRectangle(cornerRadius: NodeTextStyle.cornerRadius)
                                .fill(Color(nsColor: .windowBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: NodeTextStyle.cornerRadius)
                                        .stroke(
                                            isEditing
                                                ? Color(nsColor: .systemPink)
                                                : (isFocused
                                                    ? Color.accentColor : Color(nsColor: .separatorColor)),
                                            lineWidth: (isEditing || isFocused)
                                                ? NodeTextStyle.focusedBorderLineWidth
                                                : NodeTextStyle.borderLineWidth
                                        )
                                )
                                .overlay(alignment: .topLeading) {
                                    if editingContext?.nodeID == node.id {
                                        NodeTextEditor(
                                            text: editingTextBinding(for: node.id),
                                            nodeWidth: CGFloat(node.bounds.width),
                                            zoomScale: zoomScale,
                                            selectAllOnFirstFocus: false,
                                            initialCursorPlacement: editingContext?.initialCursorPlacement ?? .end,
                                            initialTypingEvent: editingContext?.initialTypingEvent,
                                            onLayoutMetricsChange: { metrics in
                                                updateEditingNodeLayout(for: node.id, metrics: metrics)
                                            },
                                            onCommit: {
                                                commitNodeEditing()
                                            },
                                            onCancel: {
                                                cancelNodeEditing()
                                            }
                                        )
                                        .padding(NodeTextStyle.editorContainerPadding * CGFloat(zoomScale))
                                    } else {
                                        nonEditingNodeText(
                                            text: node.text ?? "",
                                            nodeWidth: node.bounds.width,
                                            zoomScale: zoomScale
                                        )
                                    }
                                }
                                .overlay(alignment: .trailing) {
                                    if isCollapsedRoot {
                                        Image(systemName: "chevron.right.circle.fill")
                                            .foregroundStyle(
                                                isFocused
                                                    ? Color.accentColor
                                                    : Color(nsColor: .secondaryLabelColor)
                                            )
                                            .font(
                                                .system(
                                                    size: NodeTextStyle.collapsedBadgeFontSize
                                                        * CGFloat(zoomScale),
                                                    weight: .semibold
                                                )
                                            )
                                            .offset(
                                                x: NodeTextStyle.collapsedBadgeTrailingOffset
                                                    * CGFloat(zoomScale)
                                            )
                                    }
                                }
                                .frame(
                                    width: CGFloat(renderedNode.bounds.width),
                                    height: CGFloat(renderedNode.bounds.height),
                                    alignment: .topLeading
                                )
                                .position(
                                    x: CGFloat(renderedNode.bounds.x + (renderedNode.bounds.width / 2)),
                                    y: CGFloat(renderedNode.bounds.y + (renderedNode.bounds.height / 2))
                                )
                        }
                    }
                }
                .frame(
                    width: viewportSize.width,
                    height: viewportSize.height,
                    alignment: .topLeading
                )
                if isCommandPalettePresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .allowsHitTesting(false)
                }
                CanvasHotkeyCaptureView(isEnabled: editingContext == nil && !isCommandPalettePresented) { event in
                    if hotkeyTranslator.shouldOpenCommandPalette(event) {
                        openCommandPalette()
                        return true
                    }
                    if let zoomAction = hotkeyTranslator.zoomAction(event) {
                        applyZoom(action: zoomAction)
                        return true
                    }
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
                        let displayNodesByID = Dictionary(uniqueKeysWithValues: displayNodes.map { ($0.id, $0) })
                        return handleTypingInputStart(event, nodesByID: displayNodesByID)
                    }
                    // Returning true tells the capture view to stop responder-chain propagation.
                    Task { await viewModel.apply(commands: commands) }
                    return true
                }
                .frame(width: 1, height: 1)
                // Keep key capture active without intercepting canvas rendering.
                .allowsHitTesting(false)
                CanvasScrollWheelMonitorView(isEnabled: true) { event in
                    guard !isCommandPalettePresented else {
                        return false
                    }
                    let translation = CanvasViewportPanPolicy.scrollWheelTranslation(
                        deltaX: event.scrollingDeltaX,
                        deltaY: event.scrollingDeltaY,
                        hasPreciseDeltas: event.hasPreciseScrollingDeltas
                    )
                    manualPanOffset = CanvasViewportPanPolicy.updatedManualPanOffset(
                        current: manualPanOffset,
                        translation: translation
                    )
                    return true
                }
                .frame(width: 1, height: 1)
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
            .onAppear {
                applyFocusVisibilityRule(viewportSize: viewportSize)
            }
            .onChange(of: viewModel.focusedNodeID) { _ in
                applyFocusVisibilityRule(viewportSize: viewportSize)
            }
            .onChange(of: viewModel.nodes) { _ in
                applyFocusVisibilityRule(viewportSize: viewportSize)
            }
            .onChange(of: editingContext) { _ in
                applyFocusVisibilityRule(viewportSize: viewportSize)
            }
            .onChange(of: viewportSize) { _ in
                applyFocusVisibilityRule(viewportSize: viewportSize)
            }
            .onChange(of: zoomScale) { _ in
                applyFocusVisibilityRule(viewportSize: viewportSize)
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
                        let measuredLayout = measuredNodeLayout(
                            text: node.text ?? "",
                            nodeWidth: node.bounds.width
                        )
                        editingContext = NodeEditingContext(
                            nodeID: nodeID,
                            text: node.text ?? "",
                            nodeWidth: node.bounds.width,
                            nodeHeight: Double(measuredLayout.nodeHeight),
                            initialCursorPlacement: .end,
                            initialTypingEvent: nil
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
        .onChange(of: commandPaletteQuery) { _ in
            selectedCommandPaletteIndex = 0
        }
        .onChange(of: isCommandPalettePresented) { isVisible in
            if !isVisible {
                commandPaletteQuery = ""
                selectedCommandPaletteIndex = 0
            }
        }
        .onReceive(viewModel.$viewportIntent) { viewportIntent in
            guard let viewportIntent else {
                return
            }
            switch viewportIntent {
            case .resetManualPanOffset:
                manualPanOffset = .zero
                hasInitializedCameraAnchor = false
                cameraAnchorPoint = .zero
            }
            viewModel.consumeViewportIntent()
        }
    }
}
// swiftlint:enable type_body_length
