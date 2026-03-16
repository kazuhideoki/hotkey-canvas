// 背景: Collision body は実 node と複数 node cluster の両方を安定して識別する必要がある。
// 責務: collision body 専用の identifier 空間を提供し、node ID との衝突を防ぐ。
/// collision body 専用の immutable identifier。
public enum CanvasCollisionBodyID: Hashable, Sendable {
    /// 単一 node を表す collision body identifier。
    case node(CanvasNodeID)
    /// 複数 node cluster を表す collision body identifier。
    case cluster(nodeIDs: [CanvasNodeID])

    /// 複数 node 用の決定的 cluster identifier を生成する。
    /// - Parameter nodeIDs: cluster に含まれる node identifier 群。
    public static func cluster(nodeIDs: Set<CanvasNodeID>) -> CanvasCollisionBodyID {
        .cluster(nodeIDs: nodeIDs.sorted { $0.rawValue < $1.rawValue })
    }
}
