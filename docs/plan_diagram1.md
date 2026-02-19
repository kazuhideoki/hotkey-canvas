# Diagram mode 設計メモ（第1回）

## 目的

- 現状の Tree モード中心実装から、キーボードで Diagram を作成できる本丸機能へ進む。
- 1つのキャンバス内で Tree と Diagram を混在させ、シームレスに編集できる設計を目指す。

## 現状認識

- 現行は `CanvasGraph` を中心に、`ApplyCanvasCommandsUseCase` + `CanvasCommandPipelineCoordinator` で処理している。
- パイプラインには Tree 前提の段（`needsTreeLayout`）があり、モード境界が明示されていない。
- `CanvasEdgeRelationType` は拡張可能で、データ構造自体は汎用化の余地がある。

## 議論で確認した論点

### 1. キャンバス全体モードか、エリア単位モードか

- 当初案:
  - `Canvas全体モード(tree/diagram)` を先に入れると段階導入しやすい。
- ユーザー意図:
  - 1キャンバス内に Tree と Diagram を共存させたい。
  - 全体モード切替忘れによる意図しない編集を避けたい。
- 現時点の合意方向:
  - `エリア単位モード` を採用する方向が妥当。

### 2. データ構造を共通化するか、モデルを分離するか

- 懸念:
  - 「汎用Model + 属性追加」を過剰に進めると、拡張性を逆に損なう可能性がある。
- 現時点の判断:
  - `CanvasGraph/CanvasNode/CanvasEdge` は共通基盤として維持。
  - モード差分はモデル分岐ではなく、`Service/Dispatcher` で表現する。
  - つまり「構造は共通、意味論はエリアポリシーで分離」。
- 補足:
  - いきなり Tree用/Diagram用のモデルを完全分離すると、境界またぎ編集や Undo/Redo が複雑化しやすい。

### 3. Command の入口とロジック分離

- 入口は単一（`CanvasEditingInputPort.apply(commands:)`）を維持する。
- 実行時に「フォーカス中ノードが属するエリアのモード」でディスパッチする。
- 非対応コマンドは暗黙 no-op ではなく、明示的な Domain/Application エラーで返す。

## 目指す初期設計（ドラフト）

### A. エリアモデル追加

- `CanvasArea`（仮）
  - `id`
  - `nodeIDs`
  - `editingMode` (`tree` / `diagram`)

### B. ポリシー分離

- `TreeAreaPolicyService`
- `DiagramAreaPolicyService`
- `AreaPolicyDispatcher`
  - 対象エリアを解決し、許可コマンド・レイアウト・整合性ルールを切り替える。

### C. 変換は別コマンド

- モード変換は暗黙切替時に行わず、明示コマンドで実施する。
- 例: `convertAreaMode(areaID:to:)`
- 変換失敗時は理由を返し、握り潰さない。

## 初期段階で準備しておくべきこと

- エリア境界の定義方法（手動/自動生成、安定ID戦略）
- コマンド適用時の対象エリア解決規則
- エリア跨ぎエッジの扱い（許可/制限/可視化）
- Undo/Redo の整合性（エリアモード変更・変換コマンドを含む）
- テスト観点の先行固定
  - 混在キャンバスでの決定的なコマンド結果
  - 非対応コマンドのエラー契約
  - 変換コマンドの成功/失敗条件

## 未確定事項（次フェーズで設計）

- `CanvasArea` を Domain のどこに置くか（Model/Service 境界）
- エリア所属の更新契約（ノード追加/削除/分割/統合時）
- `CanvasMutationEffects` の再設計（Tree 固有フラグからの脱却）
- ホットキーカタログをエリアモード対応でどう解決するか

## 次アクション案

1. `CanvasArea` と `editingMode` の最小型を Domain に定義する。
2. `apply` のディスパッチをエリアモード解決ベースに置き換える設計を作る。
3. 変換コマンド `convertAreaMode` の入力・エラー契約を決める。
4. 上記を `docs/domain.md` と整合する形で追記する。
