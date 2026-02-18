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
    @State private var commandPaletteQuery: String = ""
    @State private var isCommandPalettePresented = false
    @State private var selectedCommandPaletteIndex: Int = 0
    @State private var manualPanOffset: CGSize = .zero
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
        let branchXByParentAndDirection = CanvasEdgeRouting.branchXByParentAndDirection(
            edges: viewModel.edges,
            nodesByID: nodesByID
        )
        return GeometryReader { geometryProxy in
            let viewportSize = CGSize(
                width: max(geometryProxy.size.width, Self.minimumCanvasWidth),
                height: max(geometryProxy.size.height, Self.minimumCanvasHeight)
            )
            let autoCenterOffset = cameraOffset(for: displayNodes, viewportSize: viewportSize)
            let cameraOffset = CanvasViewportPanPolicy.combinedOffset(
                autoCenterOffset: autoCenterOffset,
                manualPanOffset: manualPanOffset,
                activeDragOffset: .zero
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

                        TextField("Search commands", text: $commandPaletteQuery)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal, 12)
                            .padding(.top, 8)

                        Rectangle()
                            .fill(Color(nsColor: .separatorColor))
                            .frame(height: 1)
                            .padding(.top, 10)

                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(commandPaletteItems.enumerated()), id: \.element.id) { (index, item) in
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
                                        index == selectedCommandPaletteIndex ? Color.accentColor.opacity(0.2) : .clear
                                    )
                                    .onTapGesture {
                                        selectedCommandPaletteIndex = index
                                        executeSelectedCommand(item)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 280)
                    }
                    .frame(width: 520)
                    .background(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                    )
                    .padding(.leading, 20)
                    .padding(.top, 20)
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
                                x: CGFloat(node.bounds.x + (node.bounds.width / 2)),
                                y: CGFloat(node.bounds.y + (node.bounds.height / 2))
                            )
                    }
                }
                .offset(x: cameraOffset.width, y: cameraOffset.height)

                if isCommandPalettePresented {
                    Color.clear
                        .contentShape(Rectangle())
                        .allowsHitTesting(false)
                }

                CanvasHotkeyCaptureView(isEnabled: editingContext == nil) { event in
                    if isCommandPalettePresented {
                        return handleCommandPaletteKeyDown(event)
                    }

                    if hotkeyTranslator.shouldOpenCommandPalette(event) {
                        openCommandPalette()
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
                        return handleTypingInputStart(event, nodesByID: nodesByID)
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
            }
            viewModel.consumeViewportIntent()
        }
    }
}
// swiftlint:enable type_body_length

extension CanvasView {
    fileprivate struct CommandPaletteItem: Identifiable, Equatable {
        let id: String
        let title: String
        let shortcutLabel: String
        let searchText: String
        let action: CanvasShortcutAction
    }

    fileprivate static let commandPaletteEscapeKeyCode: UInt16 = 53
    fileprivate static let commandPaletteReturnKeyCode: UInt16 = 36
    fileprivate static let commandPaletteUpArrowKeyCode: UInt16 = 126
    fileprivate static let commandPaletteDownArrowKeyCode: UInt16 = 125
    fileprivate static let commandPaletteBackspaceKeyCode: UInt16 = 51
    fileprivate static let commandPaletteForwardDeleteKeyCode: UInt16 = 117

    fileprivate func openCommandPalette() {
        isCommandPalettePresented = true
        selectedCommandPaletteIndex = 0
        commandPaletteQuery = ""
    }

    fileprivate func closeCommandPalette() {
        isCommandPalettePresented = false
    }

    // swiftlint:disable cyclomatic_complexity
    fileprivate func handleCommandPaletteKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode

        if keyCode == Self.commandPaletteEscapeKeyCode {
            closeCommandPalette()
            return true
        }

        if keyCode == Self.commandPaletteReturnKeyCode {
            executeSelectedCommandIfNeeded()
            return true
        }

        if keyCode == Self.commandPaletteUpArrowKeyCode {
            guard !filteredCommandPaletteItems().isEmpty else {
                return true
            }
            selectedCommandPaletteIndex = max(0, selectedCommandPaletteIndex - 1)
            return true
        }

        if keyCode == Self.commandPaletteDownArrowKeyCode {
            guard !filteredCommandPaletteItems().isEmpty else {
                return true
            }
            let maxIndex = max(0, filteredCommandPaletteItems().count - 1)
            selectedCommandPaletteIndex = min(maxIndex, selectedCommandPaletteIndex + 1)
            return true
        }

        if keyCode == Self.commandPaletteBackspaceKeyCode {
            guard !commandPaletteQuery.isEmpty else {
                return true
            }
            commandPaletteQuery.removeLast()
            return true
        }

        if keyCode == Self.commandPaletteForwardDeleteKeyCode {
            guard !commandPaletteQuery.isEmpty else {
                return true
            }
            commandPaletteQuery.removeLast()
            return true
        }

        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let disallowed: NSEvent.ModifierFlags = [.command, .control, .option, .function]
        guard modifiers.isDisjoint(with: disallowed) else {
            return true
        }

        guard let characters = event.charactersIgnoringModifiers, let first = characters.first else {
            return false
        }
        guard first != "\r", first != "\n" else {
            return true
        }
        guard first.isASCII, first.isLetter || first.isNumber || first.isPunctuation || first == " " else {
            // Ignore non-printable and function-key artifacts so query filtering stays stable.
            return true
        }
        commandPaletteQuery.append(contentsOf: String(first).lowercased())
        return true
    }
    // swiftlint:enable cyclomatic_complexity

    fileprivate func filteredCommandPaletteItems() -> [CommandPaletteItem] {
        let orderedItems = defaultCommandPaletteItems()
            .sorted { lhs, rhs in
                lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }

        guard !commandPaletteQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return orderedItems
        }

        return orderedItems.filter { item in
            matchesCommandPaletteQuery(item.searchText, commandPaletteQuery)
        }
    }

    fileprivate func defaultCommandPaletteItems() -> [CommandPaletteItem] {
        CanvasShortcutCatalogService.commandPaletteDefinitions().compactMap { definition in
            guard definition.isVisibleInCommandPalette else {
                return nil
            }
            let searchText = ([definition.name, definition.shortcutLabel] + definition.searchTokens).joined(
                separator: " "
            )
            return CommandPaletteItem(
                id: definition.id.rawValue,
                title: definition.name,
                shortcutLabel: definition.shortcutLabel,
                searchText: searchText,
                action: definition.action
            )
        }
    }

    fileprivate func executeSelectedCommandIfNeeded() {
        let commandItems = filteredCommandPaletteItems()
        guard !commandItems.isEmpty else {
            return
        }
        let selectedIndex = min(max(0, selectedCommandPaletteIndex), commandItems.count - 1)
        executeSelectedCommand(commandItems[selectedIndex])
    }

    fileprivate func executeSelectedCommand(_ item: CommandPaletteItem) {
        switch item.action {
        case .apply(let commands):
            Task {
                await viewModel.apply(commands: commands)
            }
        case .undo:
            Task {
                await viewModel.undo()
            }
        case .redo:
            Task {
                await viewModel.redo()
            }
        case .openCommandPalette:
            return
        }
        closeCommandPalette()
    }

    fileprivate func matchesCommandPaletteQuery(_ value: String, _ rawQuery: String) -> Bool {
        let valueText = value.lowercased()
        let query = rawQuery.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return true
        }

        var valueIndex = valueText.startIndex
        for queryCharacter in query {
            while valueIndex != valueText.endIndex, valueText[valueIndex] != queryCharacter {
                valueIndex = valueText.index(after: valueIndex)
            }
            guard valueIndex != valueText.endIndex else {
                return false
            }
            valueIndex = valueText.index(after: valueIndex)
        }
        return true
    }
}
