import Foundation

extension CanvasCollisionResolutionService {
    static func shapesOverlap(
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

    static func requiredSeparation(
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

    static func preferredSeparation(
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

    static func moveUnitVector(for direction: CanvasNodeMoveDirection) -> (dx: Int, dy: Int) {
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

    static func requiredTranslationAlongX(
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

    static func requiredTranslationAlongY(
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
