import Domain

// Background: Command dispatch uses shared classification helpers to keep the main dispatch file readable.
// Responsibility: Build resolved command context and classify command families for dispatch.
extension ApplyCanvasCommandsUseCase {
    func resolvedCommandContext(
        for command: CanvasCommand,
        in graph: CanvasGraph
    ) throws -> ResolvedCommandContext {
        let normalizedCommand = normalize(command: command, in: graph)
        let resolvedAreaID = try resolveAreaID(for: normalizedCommand, in: graph).get()
        let resolvedArea = try CanvasAreaMembershipService.area(withID: resolvedAreaID, in: graph).get()
        return ResolvedCommandContext(
            command: normalizedCommand,
            areaID: resolvedAreaID,
            area: resolvedArea,
            executionContext: makeExecutionContext(
                for: normalizedCommand,
                in: graph,
                editingMode: resolvedArea.editingMode
            )
        )
    }

    static func isAreaManagementCommand(_ command: CanvasCommand) -> Bool {
        switch command {
        case .toggleFocusedAreaEdgeShapeStyle, .convertFocusedAreaMode, .createArea, .assignNodesToArea:
            return true
        default:
            return false
        }
    }

    static func isNodeStructureCommand(_ command: CanvasCommand) -> Bool {
        switch command {
        case .addNode, .addChildNode, .addSiblingNode, .duplicateSelectionAsSibling, .connectNodes:
            return true
        default:
            return false
        }
    }
}
