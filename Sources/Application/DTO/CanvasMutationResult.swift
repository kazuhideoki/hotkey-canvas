// 背景: パイプライン実行は command mutation の出力から開始する。
// 責務: mutation 後の graph と stage effect を保持し、coordinator の分岐に渡す。
import Domain

/// パイプライン stage 適用前の command mutation 出力を表す Application 層 DTO。
struct CanvasMutationResult: Equatable, Sendable {
    let graphBeforeMutation: CanvasGraph
    let graphAfterMutation: CanvasGraph
    let effects: CanvasMutationEffects
    let areaLayoutSeedNodeID: CanvasNodeID?
    let diagramNodeLayoutSeedNodeIDs: Set<CanvasNodeID>
    let diagramNodeLayoutSeedMoveDirection: CanvasNodeMoveDirection?
    let diagramAlignmentConstraint: CanvasDiagramAlignmentConstraint?

    init(
        graphBeforeMutation: CanvasGraph,
        graphAfterMutation: CanvasGraph,
        effects: CanvasMutationEffects,
        areaLayoutSeedNodeID: CanvasNodeID? = nil,
        diagramNodeLayoutSeedNodeIDs: Set<CanvasNodeID> = [],
        diagramNodeLayoutSeedMoveDirection: CanvasNodeMoveDirection? = nil,
        diagramAlignmentConstraint: CanvasDiagramAlignmentConstraint? = nil
    ) {
        self.graphBeforeMutation = graphBeforeMutation
        self.graphAfterMutation = graphAfterMutation
        self.effects = effects
        self.areaLayoutSeedNodeID = areaLayoutSeedNodeID
        self.diagramNodeLayoutSeedNodeIDs = diagramNodeLayoutSeedNodeIDs
        self.diagramNodeLayoutSeedMoveDirection = diagramNodeLayoutSeedMoveDirection
        self.diagramAlignmentConstraint = diagramAlignmentConstraint
    }
}
