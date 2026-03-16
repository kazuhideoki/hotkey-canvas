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

        if let seedPreferredMoveDirection {
            let initialSeparation = requiredSeparation(
                moving: firstCollidedShape,
                fixed: seedShape,
                spacing: spacing,
                tieBreakDirection: bodyIDSortKey(seedBodyID) < bodyIDSortKey(firstCollidedBodyID) ? 1 : -1,
                preferredMoveDirection: seedPreferredMoveDirection
            )
            let didMoveCollided = applyTranslation(
                to: firstCollidedBodyID,
                translation: initialSeparation,
                state: &state
            )
            guard didMoveCollided else {
                return nil
            }
            return state
        }

        let initialSeparation = requiredSeparation(
            moving: firstCollidedShape,
            fixed: seedShape,
            spacing: spacing,
            tieBreakDirection: bodyIDSortKey(seedBodyID) < bodyIDSortKey(firstCollidedBodyID) ? 1 : -1
        )
        let didMoveSeed = applyTranslation(
            to: seedBodyID,
            translation: CanvasTranslation(
                dx: -(initialSeparation.dx / 2),
                dy: -(initialSeparation.dy / 2)
            ),
            state: &state
        )
        let didMoveCollided = applyTranslation(
            to: firstCollidedBodyID,
            translation: CanvasTranslation(
                dx: initialSeparation.dx / 2,
                dy: initialSeparation.dy / 2
            ),
            state: &state
        )

        guard didMoveSeed || didMoveCollided else {
            return nil
        }
        return state
    }

    private static func propagateOverlaps(
        state: inout OverlapResolutionState,
        spacing: Double,
        seedBodyID: CanvasCollisionBodyID,
        seedPreferredMoveDirection: CanvasNodeMoveDirection?,
        maxIterations: Int
    ) {
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
                    spacing: spacing,
                    seedBodyID: seedBodyID,
                    seedPreferredMoveDirection: seedPreferredMoveDirection,
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
        spacing: Double,
        seedBodyID: CanvasCollisionBodyID,
        seedPreferredMoveDirection: CanvasNodeMoveDirection?,
        state: inout OverlapResolutionState
    ) -> Bool {
        guard
            let moverShape = state.shapesByBodyID[moverBodyID],
            let targetShape = state.shapesByBodyID[targetBodyID]
        else {
            return false
        }
        guard shapesOverlap(moverShape, targetShape, spacing: spacing) else {
            return false
        }

        let separation = requiredSeparation(
            moving: targetShape,
            fixed: moverShape,
            spacing: spacing,
            tieBreakDirection: bodyIDSortKey(moverBodyID) < bodyIDSortKey(targetBodyID) ? 1 : -1,
            preferredMoveDirection: moverBodyID == seedBodyID ? seedPreferredMoveDirection : nil
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

    private static func shapesOverlap(
        _ lhs: CanvasCollisionShape,
        _ rhs: CanvasCollisionShape,
        spacing: Double
    ) -> Bool {
        let halfSpacing = max(0, spacing) / 2
        guard
            lhs.bounds.expanded(horizontal: halfSpacing, vertical: halfSpacing)
                .intersects(rhs.bounds.expanded(horizontal: halfSpacing, vertical: halfSpacing))
        else {
            return false
        }

        for lhsRect in lhs.componentRects {
            let expandedLHSRect = lhsRect.expanded(horizontal: halfSpacing, vertical: halfSpacing)
            for rhsRect in rhs.componentRects {
                let expandedRHSRect = rhsRect.expanded(horizontal: halfSpacing, vertical: halfSpacing)
                if expandedLHSRect.intersects(expandedRHSRect) {
                    return true
                }
            }
        }
        return false
    }

    private static func requiredSeparation(
        moving: CanvasCollisionShape,
        fixed: CanvasCollisionShape,
        spacing: Double,
        tieBreakDirection: Double,
        preferredMoveDirection: CanvasNodeMoveDirection? = nil
    ) -> CanvasTranslation {
        if let preferredMoveDirection,
            let preferredSeparation = preferredSeparation(
                moving: moving,
                fixed: fixed,
                spacing: spacing,
                preferredMoveDirection: preferredMoveDirection
            )
        {
            return preferredSeparation
        }

        var directionX = moving.bounds.centerX - fixed.bounds.centerX
        var directionY = moving.bounds.centerY - fixed.bounds.centerY
        if abs(directionX) <= numericEpsilon, abs(directionY) <= numericEpsilon {
            directionX = tieBreakDirection >= 0 ? 1 : -1
            directionY = 0
        }

        if abs(directionX) >= abs(directionY) {
            let sign = directionX >= 0 ? 1 : -1
            let requiredX = requiredTranslationAlongX(
                moving: moving,
                fixed: fixed,
                spacing: spacing,
                sign: sign
            )
            if abs(requiredX) > numericEpsilon {
                return CanvasTranslation(dx: requiredX, dy: 0)
            }
            let fallbackY = requiredTranslationAlongY(
                moving: moving,
                fixed: fixed,
                spacing: spacing,
                sign: directionY >= 0 ? 1 : -1
            )
            return CanvasTranslation(dx: 0, dy: fallbackY)
        }

        let sign = directionY >= 0 ? 1 : -1
        let requiredY = requiredTranslationAlongY(
            moving: moving,
            fixed: fixed,
            spacing: spacing,
            sign: sign
        )
        if abs(requiredY) > numericEpsilon {
            return CanvasTranslation(dx: 0, dy: requiredY)
        }
        let fallbackX = requiredTranslationAlongX(
            moving: moving,
            fixed: fixed,
            spacing: spacing,
            sign: directionX >= 0 ? 1 : -1
        )
        return CanvasTranslation(dx: fallbackX, dy: 0)
    }

    private static func preferredSeparation(
        moving: CanvasCollisionShape,
        fixed: CanvasCollisionShape,
        spacing: Double,
        preferredMoveDirection: CanvasNodeMoveDirection
    ) -> CanvasTranslation? {
        let unitVector = moveUnitVector(for: preferredMoveDirection)
        var candidates: [CanvasTranslation] = []

        if unitVector.dx != 0 {
            let requiredX = requiredTranslationAlongX(
                moving: moving,
                fixed: fixed,
                spacing: spacing,
                sign: unitVector.dx
            )
            if abs(requiredX) > numericEpsilon {
                candidates.append(CanvasTranslation(dx: requiredX, dy: 0))
            }
        }

        if unitVector.dy != 0 {
            let requiredY = requiredTranslationAlongY(
                moving: moving,
                fixed: fixed,
                spacing: spacing,
                sign: unitVector.dy
            )
            if abs(requiredY) > numericEpsilon {
                candidates.append(CanvasTranslation(dx: 0, dy: requiredY))
            }
        }

        return candidates.min { lhs, rhs in
            let lhsDistance = max(abs(lhs.dx), abs(lhs.dy))
            let rhsDistance = max(abs(rhs.dx), abs(rhs.dy))
            if lhsDistance != rhsDistance {
                return lhsDistance < rhsDistance
            }
            return abs(lhs.dy) > abs(rhs.dy)
        }
    }

    private static func moveUnitVector(for direction: CanvasNodeMoveDirection) -> (dx: Int, dy: Int) {
        switch direction {
        case .up:
            return (0, -1)
        case .down:
            return (0, 1)
        case .left:
            return (-1, 0)
        case .right:
            return (1, 0)
        case .upLeft:
            return (-1, -1)
        case .upRight:
            return (1, -1)
        case .downLeft:
            return (-1, 1)
        case .downRight:
            return (1, 1)
        }
    }

    private static func requiredTranslationAlongX(
        moving: CanvasCollisionShape,
        fixed: CanvasCollisionShape,
        spacing: Double,
        sign: Int
    ) -> Double {
        let halfSpacing = max(0, spacing) / 2
        var requiredTranslation: Double = 0

        for movingRect in moving.componentRects {
            let expandedMovingRect = movingRect.expanded(horizontal: halfSpacing, vertical: halfSpacing)
            for fixedRect in fixed.componentRects {
                let expandedFixedRect = fixedRect.expanded(horizontal: halfSpacing, vertical: halfSpacing)
                guard expandedMovingRect.intersects(expandedFixedRect) else {
                    continue
                }

                let candidate =
                    if sign >= 0 {
                        expandedFixedRect.maxX - expandedMovingRect.minX
                    } else {
                        expandedFixedRect.minX - expandedMovingRect.maxX
                    }

                if sign >= 0 {
                    requiredTranslation = max(requiredTranslation, candidate)
                } else {
                    requiredTranslation = min(requiredTranslation, candidate)
                }
            }
        }

        return requiredTranslation
    }

    private static func requiredTranslationAlongY(
        moving: CanvasCollisionShape,
        fixed: CanvasCollisionShape,
        spacing: Double,
        sign: Int
    ) -> Double {
        let halfSpacing = max(0, spacing) / 2
        var requiredTranslation: Double = 0

        for movingRect in moving.componentRects {
            let expandedMovingRect = movingRect.expanded(horizontal: halfSpacing, vertical: halfSpacing)
            for fixedRect in fixed.componentRects {
                let expandedFixedRect = fixedRect.expanded(horizontal: halfSpacing, vertical: halfSpacing)
                guard expandedMovingRect.intersects(expandedFixedRect) else {
                    continue
                }

                let candidate =
                    if sign >= 0 {
                        expandedFixedRect.maxY - expandedMovingRect.minY
                    } else {
                        expandedFixedRect.minY - expandedMovingRect.maxY
                    }

                if sign >= 0 {
                    requiredTranslation = max(requiredTranslation, candidate)
                } else {
                    requiredTranslation = min(requiredTranslation, candidate)
                }
            }
        }

        return requiredTranslation
    }
}
