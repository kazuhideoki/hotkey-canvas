// Background: Policy evaluation needs a stable input snapshot.
// Responsibility: Carry execution-relevant state for condition evaluation.
public struct KeymapExecutionContext: Equatable, Sendable {
    /// Editing mode selected for the target area.
    public let editingMode: CanvasEditingMode?
    /// Current operation target kind.
    public let operationTargetKind: KeymapSwitchTargetKindIntentVariant
    /// Whether there is focused node in current canvas context.
    public let hasFocusedNode: Bool
    /// Whether inline text editing is active.
    public let isEditingText: Bool
    /// Command palette modal state.
    public let isCommandPalettePresented: Bool
    /// Search modal state.
    public let isSearchPresented: Bool
    /// Connect-node selection modal state.
    public let isConnectNodeSelectionActive: Bool
    /// Add-node mode popup state.
    public let isAddNodePopupPresented: Bool
    /// Selected node count.
    public let selectedNodeCount: Int
    /// Selected edge count.
    public let selectedEdgeCount: Int

    /// Whether any modal state is currently active.
    public var isModalActive: Bool {
        isCommandPalettePresented
            || isSearchPresented
            || isConnectNodeSelectionActive
            || isAddNodePopupPresented
    }

    /// Creates an execution context snapshot.
    /// - Parameters:
    ///   - editingMode: Area editing mode.
    ///   - operationTargetKind: Current operation target kind.
    ///   - hasFocusedNode: Whether focused node exists.
    ///   - isEditingText: Whether text editing is active.
    ///   - isCommandPalettePresented: Command palette modal state.
    ///   - isSearchPresented: Search modal state.
    ///   - isConnectNodeSelectionActive: Connect-node selection state.
    ///   - isAddNodePopupPresented: Add-node popup state.
    ///   - selectedNodeCount: Number of selected nodes.
    ///   - selectedEdgeCount: Number of selected edges.
    public init(
        editingMode: CanvasEditingMode? = nil,
        operationTargetKind: KeymapSwitchTargetKindIntentVariant = .node,
        hasFocusedNode: Bool = false,
        isEditingText: Bool = false,
        isCommandPalettePresented: Bool = false,
        isSearchPresented: Bool = false,
        isConnectNodeSelectionActive: Bool = false,
        isAddNodePopupPresented: Bool = false,
        selectedNodeCount: Int = 0,
        selectedEdgeCount: Int = 0
    ) {
        self.editingMode = editingMode
        self.operationTargetKind = operationTargetKind
        self.hasFocusedNode = hasFocusedNode
        self.isEditingText = isEditingText
        self.isCommandPalettePresented = isCommandPalettePresented
        self.isSearchPresented = isSearchPresented
        self.isConnectNodeSelectionActive = isConnectNodeSelectionActive
        self.isAddNodePopupPresented = isAddNodePopupPresented
        self.selectedNodeCount = selectedNodeCount
        self.selectedEdgeCount = selectedEdgeCount
    }

    func isActive(modal: KeymapExecutionModalKind) -> Bool {
        switch modal {
        case .commandPalette:
            isCommandPalettePresented
        case .search:
            isSearchPresented
        case .connectNodeSelection:
            isConnectNodeSelectionActive
        case .addNodePopup:
            isAddNodePopupPresented
        }
    }
}
