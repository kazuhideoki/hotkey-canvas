// 背景: 通常ショートカットの操作意図を具体的な挙動へ結び付ける入力境界が必要。
// 責務: 操作意図から実行可能な操作を解決する契約を定義する。
import Domain

/// 操作意図を実行可能な操作へ解決する入力ポート。
public protocol KeymapContextActionResolver: Sendable {
    /// 通常ショートカットの操作意図を実行可能な操作へ変換する。
    /// - Parameter primitiveIntent: スコープ判定済みの操作意図。
    /// - Returns: 実行対象となる操作。
    func resolve(primitiveIntent: KeymapPrimitiveIntent) -> KeymapContextAction
}
