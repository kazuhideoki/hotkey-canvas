// Background: The canvas needs a single view that coordinates rendering, hotkeys, and inline text editing.
// Responsibility: Render nodes/edges and orchestrate transitions between hotkey mode and node-editing mode.
import AppKit
import Application
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
    @State var isAddNodeModePopupPresented = false
    @State var selectedAddNodeMode: CanvasEditingMode = .tree
    @State var hasInitializedCameraAnchor = false
    @State var cameraAnchorPoint: CGPoint = .zero
    @State var manualPanOffset: CGSize = .zero
    @State var zoomScale: Double = 1.0
    @State var zoomRatioPopupText: String?
    @State var zoomRatioPopupRequestID: UInt64 = 0
    /// Monotonic token used to ignore stale async editing-start tasks.
    @State private var pendingEditingRequestID: UInt64 = 0
    @State var connectNodeSelectionSourceNodeID: CanvasNodeID?
    @State var connectNodeSelectionTargetNodeID: CanvasNodeID?
    let hotkeyTranslator: CanvasHotkeyTranslator
    let styleSheet: CanvasStyleSheet
    private let onDisappearHandler: () -> Void
    let addNodeModeSelectionHotkeyResolver = AddNodeModeSelectionHotkeyResolver()
    let connectNodeSelectionHotkeyResolver = ConnectNodeSelectionHotkeyResolver()
    let editingStartResolver = NodeEditingStartResolver()
    var nodeTextStyle: NodeTextStyle {
        NodeTextStyle(styleSheet: styleSheet)
    }
    public init(
        viewModel: CanvasViewModel,
        hotkeyTranslator: CanvasHotkeyTranslator = CanvasHotkeyTranslator(),
        styleSheet: CanvasStyleSheet = CanvasStylePalette.defaultStyleSheet,
        onDisappear: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.hotkeyTranslator = hotkeyTranslator
        self.styleSheet = styleSheet
        onDisappearHandler = onDisappear
    }

    func styleColor(_ token: CanvasStyleColorToken) -> Color {
        CanvasStylePalette.color(token)
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
            let branchCoordinateByParentAndDirection = CanvasEdgeRouting.branchCoordinateByParentAndDirection(
                edges: viewModel.edges,
                nodesByID: nodesByID
            )
            let commandPaletteItems = filteredCommandPaletteItems()
            ZStack(alignment: .topLeading) {
                styleColor(.textBackground)
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
                                .fill(styleColor(.textBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(styleColor(.separator), lineWidth: 1)
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        Rectangle()
                            .fill(styleColor(.separator))
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
                                scrollProxy.scrollTo(
                                    commandPaletteItems[selectedIndex].id,
                                    anchor: .center
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
                            .stroke(styleColor(.separator), lineWidth: 1)
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
                            branchCoordinateByParentAndDirection: branchCoordinateByParentAndDirection
                        ) {
                            path
                                .applying(
                                    CanvasViewportTransform.affineTransform(
                                        viewportSize: viewportSize,
                                        zoomScale: zoomScale,
                                        effectiveOffset: cameraOffset
                                    )
                                )
                                .stroke(
                                    styleColor(styleSheet.edge.strokeColor),
                                    lineWidth: styleSheet.edge.lineWidth
                                )
                        }
                    }
                    ForEach(displayNodes, id: \.id) { node in
                        if let renderedNode = renderedNodesByID[node.id] {
                            let isFocused = viewModel.focusedNodeID == node.id
                            let isSelected = viewModel.selectedNodeIDs.contains(node.id)
                            let isCollapsedRoot = viewModel.collapsedRootNodeIDs.contains(node.id)
                            let isEditing = editingContext?.nodeID == node.id
                            let isDiagramNode = viewModel.diagramNodeIDs.contains(node.id)
                            let isTreeRootNode = viewModel.treeRootNodeIDs.contains(node.id)
                            let textContentAlignment = nodeTextContentAlignment(for: node.id)
                            let nodeCornerRadius: CGFloat = isDiagramNode ? 0 : nodeTextStyle.cornerRadius
                            let nodeFillColor =
                                isTreeRootNode
                                ? styleColor(styleSheet.nodeChrome.treeRootFillColor)
                                : styleColor(styleSheet.nodeChrome.defaultFillColor)
                            RoundedRectangle(cornerRadius: nodeCornerRadius)
                                .fill(nodeFillColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: nodeCornerRadius)
                                        .stroke(
                                            connectNodeSelectionBorderColor(
                                                for: node.id,
                                                isEditing: isEditing,
                                                isFocused: isFocused,
                                                isSelected: isSelected
                                            ),
                                            lineWidth: connectNodeSelectionBorderLineWidth(
                                                for: node.id,
                                                isEditing: isEditing,
                                                isFocused: isFocused,
                                                isSelected: isSelected
                                            )
                                        )
                                )
                                .overlay(alignment: .topLeading) {
                                    nodeContentOverlay(
                                        node: node,
                                        zoomScale: zoomScale,
                                        contentAlignment: textContentAlignment
                                    )
                                }
                                .overlay(alignment: .trailing) {
                                    if isCollapsedRoot {
                                        Image(systemName: "chevron.right.circle.fill")
                                            .foregroundStyle(
                                                isFocused
                                                    ? styleColor(.accent)
                                                    : styleColor(.secondaryLabel)
                                            )
                                            .font(
                                                .system(
                                                    size: nodeTextStyle.collapsedBadgeFontSize
                                                        * CGFloat(zoomScale),
                                                    weight: .semibold
                                                )
                                            )
                                            .offset(
                                                x: nodeTextStyle.collapsedBadgeTrailingOffset
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
                .allowsHitTesting(!isAddNodeModePopupPresented)
                if isAddNodeModePopupPresented {
                    SelectionPopup(
                        styleSheet: styleSheet,
                        title: "Select Node Mode",
                        footerText: "Press Enter to confirm, Esc to cancel.",
                        options: addNodeModeSelectionOptions(),
                        selectedOptionID: addNodeModeOptionID(for: selectedAddNodeMode),
                        onSelectOption: { optionID in
                            selectedAddNodeMode = addNodeMode(from: optionID)
                        },
                        onConfirmOption: { optionID in
                            commitAddNodeModeSelection(addNodeMode(from: optionID))
                        },
                        onDismiss: {
                            dismissAddNodeModeSelectionPopup()
                        }
                    )
                    .zIndex(11)
                }
                connectNodeSelectionBanner()
                if let zoomRatioPopupText {
                    ZoomRatioPopup(styleSheet: styleSheet, text: zoomRatioPopupText)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .allowsHitTesting(false)
                        .zIndex(12)
                        .transition(.opacity)
                }
                if isCommandPalettePresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .allowsHitTesting(false)
                }
                CanvasHotkeyCaptureView(isEnabled: editingContext == nil && !isCommandPalettePresented) { event in
                    handleCanvasHotkeyEvent(event, displayNodes: displayNodes)
                }
                .frame(width: 1, height: 1)
                // Keep key capture active without intercepting canvas rendering.
                .allowsHitTesting(false)
                CanvasScrollWheelMonitorView(isEnabled: true) { event in
                    guard !isCommandPalettePresented, !isAddNodeModePopupPresented else {
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
                let shouldPresentAddNodeModeSelection = await viewModel.onAppear()
                guard shouldPresentAddNodeModeSelection else {
                    return
                }
                presentAddNodeModeSelectionPopup()
            }
            .onAppear {
                applyFocusVisibilityRule(viewportSize: viewportSize)
            }
            .onChange(of: viewModel.focusedNodeID) { _ in
                applyFocusVisibilityRule(viewportSize: viewportSize)
                synchronizeConnectNodeSelectionState()
            }
            .onChange(of: viewModel.nodes) { _ in
                applyFocusVisibilityRule(viewportSize: viewportSize)
                synchronizeConnectNodeSelectionState()
            }
            .onChange(of: viewModel.areaIDByNodeID) { _ in
                synchronizeConnectNodeSelectionState()
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
                        let measuredHeight = measuredNodeHeightForEditing(
                            text: node.text ?? "",
                            measuredTextHeight: Double(measuredLayout.nodeHeight),
                            node: node
                        )
                        editingContext = NodeEditingContext(
                            nodeID: nodeID,
                            text: node.text ?? "",
                            nodeWidth: node.bounds.width,
                            nodeHeight: measuredHeight,
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
        .onDisappear(perform: onDisappearHandler)
    }
}
// swiftlint:enable type_body_length
