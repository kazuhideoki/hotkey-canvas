// 背景: 衝突解消では 1 node または移動中 node 群を表す安定した単位が必要。
// 責務: 一緒に動く node ID 群へ collision shape を結び付ける。
/// 全 member node を同じ移動量で動かす immutable collision body。
public struct CanvasCollisionBody: Equatable, Sendable {
    /// 衝突解消で使う決定的 identifier。
    public let id: CanvasCollisionBodyID
    /// この body が移動したとき同時に動く node identifier 群。
    public let nodeIDs: Set<CanvasNodeID>
    /// 重なり判定に使う collision shape。
    public let shape: CanvasCollisionShape

    /// collision body を生成する。
    /// - Parameters:
    ///   - id: 決定的な body identifier。
    ///   - nodeIDs: この body と一緒に動く node 群。
    ///   - shape: body の collision shape。
    public init(
        id: CanvasCollisionBodyID,
        nodeIDs: Set<CanvasNodeID>,
        shape: CanvasCollisionShape
    ) {
        self.id = id
        self.nodeIDs = nodeIDs
        self.shape = shape
    }
}
