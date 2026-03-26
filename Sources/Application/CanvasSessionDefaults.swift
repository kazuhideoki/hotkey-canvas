// 背景: セッション関連の既定値が複数箇所に分散すると、変更時に方針がずれやすい。
// 責務: セッション運用に関する Application 層の共有既定値を定義する。

/// Canvas session の共有既定値。
public enum CanvasSessionDefaults {
    /// 新規セッションとユースケースが共有する undo 履歴の既定上限。
    public static let maxHistoryCount = 100
}
