// 背景: Diagram の衝突解消では、移動 node 間の gap を保てる非凸 shape が必要。
// 責務: 1 つの immutable collision shape を軸平行矩形群の union として表現する。
/// 1 個以上の軸平行矩形で構成される immutable collision shape。
public struct CanvasCollisionShape: Equatable, Sendable {
    /// collision shape を構成する矩形群。
    public let componentRects: [CanvasRect]
    /// shape 全体を内包する軸平行 bounds。
    public let bounds: CanvasRect

    /// 単一矩形の collision shape を生成する。
    /// - Parameter rect: shape を構成する矩形。
    public init(rect: CanvasRect) {
        componentRects = [rect]
        bounds = rect
    }

    /// 複数矩形からなる collision shape を生成する。
    /// - Parameter rects: shape を構成する空でない矩形列。
    public init(rects: [CanvasRect]) {
        precondition(rects.isEmpty == false, "CanvasCollisionShape requires at least one rectangle")
        componentRects = rects
        bounds = Self.enclosingBounds(of: rects)
    }
}

extension CanvasCollisionShape {
    /// 指定オフセットだけ平行移動した shape を返す。
    /// - Parameters:
    ///   - dx: 水平方向の移動量。
    ///   - dy: 垂直方向の移動量。
    /// - Returns: 平行移動後の collision shape。
    public func translated(dx: Double, dy: Double) -> CanvasCollisionShape {
        if componentRects.count == 1, let rect = componentRects.first {
            return CanvasCollisionShape(rect: rect.translated(dx: dx, dy: dy))
        }
        return CanvasCollisionShape(
            rects: componentRects.map { rect in
                rect.translated(dx: dx, dy: dy)
            }
        )
    }

    private static func enclosingBounds(of rects: [CanvasRect]) -> CanvasRect {
        let firstRect = rects[0]
        var minX = firstRect.minX
        var minY = firstRect.minY
        var maxX = firstRect.maxX
        var maxY = firstRect.maxY

        for rect in rects.dropFirst() {
            minX = min(minX, rect.minX)
            minY = min(minY, rect.minY)
            maxX = max(maxX, rect.maxX)
            maxY = max(maxY, rect.maxY)
        }

        return CanvasRect(
            minX: minX,
            minY: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}
