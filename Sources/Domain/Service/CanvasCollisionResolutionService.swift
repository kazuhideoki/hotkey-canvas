import Foundation

// 背景: Diagram node move では area 外形に頼らず、非凸 node cluster の重なりを解消する必要がある。
// 責務: 1 個以上の矩形からなる collision body 間の重なりを伝播的に解消する。
/// collision body 間の伝播的な重なり解消を行う pure domain service。
public enum CanvasCollisionResolutionService {
    /// 無視できる微小移動量を判定する epsilon。
    static let numericEpsilon: Double = 1e-9

    // MARK: - Public API

    /// seed body から cardinal direction の移動を伝播して body 間の重なりを解消する。
    /// - Parameters:
    ///   - bodies: 解消対象の collision body 群。
    ///   - seedBodyID: 衝突解消の起点となる body identifier。
    ///   - minimumSpacing: 解消後に要求する最小間隔。
    ///   - seedPreferredMoveDirection: seed body の slot を保つため優先したい移動方向。
    ///   - maxIterations: 伝播移動の最大回数。
    /// - Returns: body identifier ごとの累積移動量。
    public static func resolveOverlaps(
        bodies: [CanvasCollisionBody],
        seedBodyID: CanvasCollisionBodyID,
        minimumSpacing: Double = 0,
        seedPreferredMoveDirection: CanvasNodeMoveDirection? = nil,
        maxIterations: Int = 1_024
    ) -> [CanvasCollisionBodyID: CanvasTranslation] {
        guard bodies.count > 1, maxIterations > 0 else {
            return [:]
        }

        guard
            var state = makeInitialResolutionState(
                bodies: bodies,
                seedBodyID: seedBodyID,
                spacing: max(0, minimumSpacing),
                seedPreferredMoveDirection: seedPreferredMoveDirection
            )
        else {
            return [:]
        }

        propagateOverlaps(
            state: &state,
            spacing: max(0, minimumSpacing),
            seedBodyID: seedBodyID,
            seedPreferredMoveDirection: seedPreferredMoveDirection,
            maxIterations: maxIterations
        )
        return state.translationsByBodyID.filter { _, translation in
            translation.isZero == false
        }
    }
}

extension CanvasCollisionResolutionService {
    struct OverlapResolutionState {
        var shapesByBodyID: [CanvasCollisionBodyID: CanvasCollisionShape]
        var translationsByBodyID: [CanvasCollisionBodyID: CanvasTranslation]
        var propagationQueue: [CanvasCollisionBodyID]
    }

    private struct PropagationContext {
        let spacing: Double
        let seedBodyID: CanvasCollisionBodyID
        let seedPreferredMoveDirection: CanvasNodeMoveDirection?
    }

    private struct InitialSeparationContext {
        let seedBodyID: CanvasCollisionBodyID
        let seedShape: CanvasCollisionShape
        let firstCollidedBodyID: CanvasCollisionBodyID
        let firstCollidedShape: CanvasCollisionShape
        let spacing: Double
        let tieBreakDirection: Double
        let seedPreferredMoveDirection: CanvasNodeMoveDirection?
    }

    private static func makeInitialResolutionState(
        bodies: [CanvasCollisionBody],
        seedBodyID: CanvasCollisionBodyID,
        spacing: Double,
        seedPreferredMoveDirection: CanvasNodeMoveDirection?
    ) -> OverlapResolutionState? {
        let shapesByBodyID = Dictionary(
            uniqueKeysWithValues: bodies.map { ($0.id, $0.shape) }
        )
        guard
            let seedShape = shapesByBodyID[seedBodyID],
            let firstCollidedBodyID = firstOverlappedBodyID(
                of: seedBodyID,
                in: shapesByBodyID,
                spacing: spacing
            ),
            let firstCollidedShape = shapesByBodyID[firstCollidedBodyID]
        else {
            return nil
        }

        var state = OverlapResolutionState(
            shapesByBodyID: shapesByBodyID,
            translationsByBodyID: [:],
            propagationQueue: [seedBodyID, firstCollidedBodyID]
        )

        let context = InitialSeparationContext(
            seedBodyID: seedBodyID,
            seedShape: seedShape,
            firstCollidedBodyID: firstCollidedBodyID,
            firstCollidedShape: firstCollidedShape,
            spacing: spacing,
            tieBreakDirection: bodyIDSortKey(seedBodyID) < bodyIDSortKey(firstCollidedBodyID) ? 1 : -1,
            seedPreferredMoveDirection: seedPreferredMoveDirection
        )
        let didApplyInitialSeparation = applyInitialSeparation(
            context: context,
            state: &state
        )
        guard didApplyInitialSeparation else {
            return nil
        }
        return state
    }

    private static func applyInitialSeparation(
        context: InitialSeparationContext,
        state: inout OverlapResolutionState
    ) -> Bool {
        if let seedPreferredMoveDirection = context.seedPreferredMoveDirection {
            let initialSeparation = requiredSeparation(
                moving: context.firstCollidedShape,
                fixed: context.seedShape,
                spacing: context.spacing,
                tieBreakDirection: context.tieBreakDirection,
                preferredMoveDirection: seedPreferredMoveDirection
            )
            return applyTranslation(
                to: context.firstCollidedBodyID,
                translation: initialSeparation,
                state: &state
            )
        }

        let initialSeparation = requiredSeparation(
            moving: context.firstCollidedShape,
            fixed: context.seedShape,
            spacing: context.spacing,
            tieBreakDirection: context.tieBreakDirection
        )
        let didMoveSeed = applyTranslation(
            to: context.seedBodyID,
            translation: CanvasTranslation(
                dx: -(initialSeparation.dx / 2),
                dy: -(initialSeparation.dy / 2)
            ),
            state: &state
        )
        let didMoveCollided = applyTranslation(
            to: context.firstCollidedBodyID,
            translation: CanvasTranslation(
                dx: initialSeparation.dx / 2,
                dy: initialSeparation.dy / 2
            ),
            state: &state
        )

        guard didMoveSeed || didMoveCollided else {
            return false
        }
        return true
    }

    private static func propagateOverlaps(
        state: inout OverlapResolutionState,
        spacing: Double,
        seedBodyID: CanvasCollisionBodyID,
        seedPreferredMoveDirection: CanvasNodeMoveDirection?,
        maxIterations: Int
    ) {
        let context = PropagationContext(
            spacing: spacing,
            seedBodyID: seedBodyID,
            seedPreferredMoveDirection: seedPreferredMoveDirection
        )
        var movementCount = 0

        while !state.propagationQueue.isEmpty, movementCount < maxIterations {
            let moverBodyID = state.propagationQueue.removeFirst()
            let targetBodyIDs = state.shapesByBodyID.keys
                .filter { $0 != moverBodyID }
                .sorted(by: compareBodyID)

            for targetBodyID in targetBodyIDs where movementCount < maxIterations {
                if moveTargetBodyIfNeeded(
                    moverBodyID: moverBodyID,
                    targetBodyID: targetBodyID,
                    context: context,
                    state: &state
                ) {
                    movementCount += 1
                }
            }
        }
    }

    private static func moveTargetBodyIfNeeded(
        moverBodyID: CanvasCollisionBodyID,
        targetBodyID: CanvasCollisionBodyID,
        context: PropagationContext,
        state: inout OverlapResolutionState
    ) -> Bool {
        guard
            let moverShape = state.shapesByBodyID[moverBodyID],
            let targetShape = state.shapesByBodyID[targetBodyID]
        else {
            return false
        }
        guard shapesOverlap(moverShape, targetShape, spacing: context.spacing) else {
            return false
        }

        let separation = requiredSeparation(
            moving: targetShape,
            fixed: moverShape,
            spacing: context.spacing,
            tieBreakDirection: bodyIDSortKey(moverBodyID) < bodyIDSortKey(targetBodyID) ? 1 : -1,
            preferredMoveDirection: moverBodyID == context.seedBodyID ? context.seedPreferredMoveDirection : nil
        )
        let didMoveTarget = applyTranslation(
            to: targetBodyID,
            translation: separation,
            state: &state
        )
        guard didMoveTarget else {
            return false
        }

        state.propagationQueue.append(targetBodyID)
        return true
    }

    private static func firstOverlappedBodyID(
        of bodyID: CanvasCollisionBodyID,
        in shapesByBodyID: [CanvasCollisionBodyID: CanvasCollisionShape],
        spacing: Double
    ) -> CanvasCollisionBodyID? {
        guard let sourceShape = shapesByBodyID[bodyID] else {
            return nil
        }

        let sortedTargetBodyIDs = shapesByBodyID.keys
            .filter { $0 != bodyID }
            .sorted(by: compareBodyID)

        for targetBodyID in sortedTargetBodyIDs {
            guard let targetShape = shapesByBodyID[targetBodyID] else {
                continue
            }
            if shapesOverlap(sourceShape, targetShape, spacing: spacing) {
                return targetBodyID
            }
        }

        return nil
    }

    private static func applyTranslation(
        to bodyID: CanvasCollisionBodyID,
        translation: CanvasTranslation,
        state: inout OverlapResolutionState
    ) -> Bool {
        guard abs(translation.dx) > numericEpsilon || abs(translation.dy) > numericEpsilon else {
            return false
        }
        guard let currentShape = state.shapesByBodyID[bodyID] else {
            return false
        }

        state.shapesByBodyID[bodyID] = currentShape.translated(
            dx: translation.dx,
            dy: translation.dy
        )
        let currentTranslation = state.translationsByBodyID[bodyID] ?? .zero
        state.translationsByBodyID[bodyID] = CanvasTranslation(
            dx: currentTranslation.dx + translation.dx,
            dy: currentTranslation.dy + translation.dy
        )
        return true
    }
}

extension CanvasCollisionResolutionService {
    private static func compareBodyID(
        _ lhs: CanvasCollisionBodyID,
        _ rhs: CanvasCollisionBodyID
    ) -> Bool {
        bodyIDSortKey(lhs) < bodyIDSortKey(rhs)
    }

    private static func bodyIDSortKey(_ bodyID: CanvasCollisionBodyID) -> String {
        switch bodyID {
        case .node(let nodeID):
            return "node:\(nodeID.rawValue)"
        case .cluster(let nodeIDs):
            let suffix = nodeIDs.map(\.rawValue).joined(separator: ",")
            return "cluster:\(suffix)"
        }
    }
}
