# Keymap 有効化条件の宣言的管理化計画

## 1. 目的

- keymap の「有効 / 無効」を各層で分散実装している現状を改善し、Domain で一元的に宣言する。
- 挙動は本スコープ内で変更しない（互換性を崩さない）。
- 将来のルール追加時に、意図（Intent）と実行可否を同じ場所で管理できる状態を作る。

## 2. 現状課題（2026-03-02時点）

- 有効性チェックが複数の場所に分散している。
  - `CanvasView+HotkeyHandling.swift` の `blocks*InAreaTarget` 系。
  - `CanvasView+CommandPalette.swift` の表示フィルタ。
  - `ApplyCanvasCommands+CommandDispatch.swift` の実行ガード（`supportedIn(mode)`）。
  - `CanvasView.swift` の hotkey capture 有効条件（`editingContext == nil` 等）。
- 条件の意味が重複し、例外追加時にどの層を触るべきか判断しづらい。
- 命令的な分岐が多く、仕様追従時に見落としが起きやすい。

## 3. 固定方針（不変条件）

- 挙動は現行実装と同値を前提にする。
- 既存のショートカット辞書の意味は維持する。
- テキスト入力モードなど、UI都合に見える条件も明示的にキー条件として定義する。
- Domain 側は「状態条件」を所有し、Adapter/UseCase は評価結果を参照して実行/表示制御する。

## 4. 設計方針

### 4.1 Domain 追加

- `KeymapExecutionContext`（読み取り専用）
  - `editingMode: CanvasEditingMode`
  - `operationTargetKind: KeymapSwitchTargetKindIntentVariant`（`.area/.node/.edge`）
  - `hasFocusedNode: Bool`
  - `isEditingText: Bool`
  - `isCommandPalettePresented: Bool`
  - `isSearchPresented: Bool`
  - `isModalActive: Bool`
  - `selectedNodeCount: Int` / `selectedEdgeCount: Int`（将来拡張用）

- `KeymapExecutionCondition`（値オブジェクト）
  - `always`
  - `notTextEditing`
  - `targetKinds([.area/.node/.edge])`
  - `requiredMode(.tree/.diagram)` / `disallowModes([.tree/.diagram])`
  - `requiresFocusedNode`
  - `requiresSelectionCount(
      minNode/maxNode/minEdge/maxEdge)` などの比較条件
  - `modalIn` / `modalOut`（必要なら）

- `KeymapExecutionRule`（定義に添付）
  - `enabledCondition: KeymapExecutionCondition`
  - `disabledCondition` を持たせる必要があれば `enabled` 側へ統合して表現。

- `KeymapExecutionPolicyResolver`
  - `func isEnabled(definition: CanvasShortcutDefinition, context: KeymapExecutionContext) -> Bool`
  - 論理的な単一責務として同値判定のみを返す。

### 4.2 モデルへの反映

- `CanvasShortcutDefinition`（現行）に `executionCondition` を追加（既定値は `always`）。
- 既存定義は全て `always` をデフォルトとし、段階導入で振る舞いを維持。

### 4.3 条件の再利用

- Command Palette の表示判定と Hotkey capture ガードは、同じ `KeymapExecutionPolicyResolver` を通す。
- `ApplyCanvasCommands` の最終ガードも `isEnabled` を再利用（Defense in Depth）。
- `blocks*InAreaTarget` などの冗長ガードは最終的に削除対象にし、必要最小限のみ残す。

### 4.4 スコープ候補（今回対象）

- Editing Mode（tree / diagram）
- Target Kind（area / node / edge）
- テキスト入力モードの on/off
- モーダル表示（Command Palette / Search / Add Node / Connect Node）
- 対象選択依存（focused node/edge の有無）

## 5. 実装フェーズ（本計画の実施順）

### Phase 1: 仕様固定と対応表作成

- 現在分散している有効/無効判定を一枚の表にまとめる。
  - 判定条件
  - 既存分岐場所
  - 期待結果（true/false）
- `docs/specs/keymap.md` に「keymap 有効化条件（宣言型）」と「対象条件の組合せ例」を追記する。

#### Phase 1 進捗（2026-03-02）

##### 現在の「有効化条件」の分散箇所

- `CanvasShortcutCatalogService` / `CanvasShortcutCatalogService+CommandPaletteVisibility` で、`commandPaletteDefinitions(context:)` の
  `commandPaletteVisibility` 判定を保持。
  - `CanvasCommandPaletteVisibility` は `always` / `requiresFocusedNode` / `requiresMode` / `requiresFocusedNodeAndMode` を持つが、現行では `requiresMode` は使われていない。
- `CanvasCommandPaletteContext` / `CanvasView+CommandPalette.swift`
  - `commandPaletteContext()` が `hasFocusedNode` と `activeEditingMode` を作る。
  - `activeEditingMode` は focused node 由来を優先し、なければ area mode が単一なら採用、複数なら `nil`。
- `CanvasView` / `CanvasHotkeyCaptureView` でハンドル開始条件を保持。
  - `editingContext == nil && !isCommandPalettePresented && !isSearchPresented`
- `CanvasView.handleCanvasHotkeyEvent`
  - `connectNodeSelection` / `addNode` の modal を先頭で吸収
  - `handleCompositeMoveHotkey`（`cmd+矢印`）を translator より先に実行
  - 解決できないキーは `NodeEditingStartResolver` でインライン編集開始判定へ委譲
- `presentConnectNodeSelectionIfPossible` は `global` の `beginConnectNodeSelection` でも追加条件を持つ
  - `connectNodeSelectionSourceNodeID == nil`
  - `focusedNodeID != nil`
  - focused node が diagram であること
  - 対象 area が存在し、接続候補が空でないこと
- `CanvasView+HotkeyHandling` で target kind ベースのブロック
  - `.area` 時の `global` ブロック: `blocksGlobalActionInAreaTarget`
  - `.area` 時の primitive ブロック: `blocksPrimitiveContextActionInAreaTarget` / `blocksCommandInAreaTarget`
- `CanvasView+EdgeTarget` で `.edge` 時の上書き
  - `handleEdgeTargetCommands(...)` が方向移動・削除・edge向き反転を再解釈
- `ApplyCanvasCommandsUseCase+CommandDispatch` の実行時ガード
  - `isCommand(normalizedCommand, supportedIn: resolvedArea.editingMode)` + policy サービス

##### 現行条件の寄せ先（同値判定の観点）

- `editing mode`（tree/diagram）
  - カタログの可視性: `commandPaletteVisibility` / `activeEditingMode`
  - 実行可否: `ApplyCanvasCommandsUseCase+CommandDispatch` の `TreeAreaPolicyService` / `DiagramAreaPolicyService`
- `target kind`（area/node/edge）
  - `.area`: `CanvasView+HotkeyHandling` が global/primitive を事前ブロック
  - `.node`: catalog/命令系の既定ルート
  - `.edge`: `CanvasView+EdgeTarget` で一部命令を edge 操作へ上書き
- `text input mode`
  - `editingContext != nil` で capture off
  - 未解決キーは `NodeEditingStartResolver` を介して文字入力開始へ
- 併せて `commandPalette/search/connect-node/add-node` の modal が capture より上位でキー受付を横取り
- `modal/state flags`
  - `isCommandPalettePresented`, `isSearchPresented`, `connectNodeSelection`, `isAddNodeModePopupPresented` は route の入り口で吸収

- `handleCompositeMoveHotkey` は `command + 上下左右矢印` を `CanvasCommand.moveNode` に直接変換し、`operationTargetKind` や `commandPaletteVisibility` を参照しない（分散条件として分離されている）

##### キーマップ定義側の現行有効化条件（初版）

- 常時有効（`commandPaletteVisibility: .always`, `isVisibleInCommandPalette: true`）
  - `undo`, `redo`, `zoomIn*`, `zoomOut*`, `addNode`
- `requiresFocusedNode`
  - `deleteSelectedOrFocusedNodes`
  - `moveFocus*`, `extendSelection*`
  - `moveNode*`, `scaleSelectedNodes*`, `copySelectionOrFocusedSubtree`, `cutSelectionOrFocusedSubtree`, `pasteClipboardAtFocusedNode`
  - `centerFocusedNode`
  - `moveFocusAcrossAreasToRoot*`
- `requiresFocusedNodeAndMode([.tree])`
  - `addChildNode`
  - `addSiblingNodeAbove / addSiblingNodeBelow`
  - `duplicateSelectionAsSibling`
  - `toggleFoldFocusedSubtree`
- `requiresFocusedNodeAndMode([.diagram])`
  - `beginConnectNodeSelection`
  - `nudgeNode*`

- `isVisibleInCommandPalette: false`
  - `openCommandPalette.commandK`, `openCommandPalette.commandShiftP`

##### コマンドパレット表示時の追加ハイドロジック（catalog 外）

- `operationTargetKind == .area` のとき `isCommandPaletteShortcutHiddenInAreaTarget` で除外
  - `CanvasShortcutAction.beginConnectNodeSelection` は常時除外
  - `CanvasShortcutAction.apply(commands:)` は `blocksCommandInAreaTarget` 準拠（`centerFocusedNode` は専用で除外）
- カタログ外の動的追加
  - `focusedNodeMarkdownToggle`（`.apply(.toggleFocusedNodeMarkdownStyle)`)  
    （`focusedNodeID != nil`）
  - `Edge: Delete Selected`（`operationTargetKind == .edge` かつ `selected/focused edge` が存在）
  - `Edge: Cycle Directionality`（`operationTargetKind == .edge` かつ `selected/focused edge` が存在）
  - `Image: Insert From Finder`（`focusedNodeID != nil`）
  - `Area: Align All Areas Vertically`（`focusedNodeID != nil`）
- `isCommandPaletteShortcutHiddenInAreaTarget` は catalog 外項目には適用されない（現状）

##### 実行時の現行同値条件（mode ベース）

- Tree mode で `supports` = true: ほぼ全体
  - false: `connectNodes`, `cycleFocusedEdgeDirectionality`（`TreeAreaPolicyService`）
- Diagram mode で `supports` = true:
  - false: `addChildNode`, `addSiblingNode`, `duplicateSelectionAsSibling`, `toggleFoldFocusedSubtree`（`DiagramAreaPolicyService`）

##### Phase 1 での最優先タスク（提案）

- 上記の要素を以下の順で 1:1 対応させる
  - `入力 capture 条件`
  - `コマンド定義（Visibility）`
  - `対象 kind 条件`
  - `mode ポリシー条件`
  - `edge-target 上書き`
- まずは値オブジェクト追加より先に「条件名」と「適用範囲」を文書化し、同値テーブルを完成させる（現フェーズの完了条件）

### Phase 2: Domain 層の土台実装

- `KeymapExecutionContext` と `KeymapExecutionCondition` を追加。
- `CanvasShortcutDefinition` の条件フィールド追加（既存 API 互換を保つ）。
- `KeymapExecutionPolicyResolver` を実装。
- `CanvasShortcutCatalogService` 側で既存 shortcut ごとの条件マッピングを定義（当面は既存同値）。

### Phase 3: 共通評価経路への接続

- Hotkey 経路
  - `CanvasView+HotkeyHandling.swift` の許可/拒否判定を `isEnabled` ベースへ差し替え。
- Command Palette 経路
  - 表示フィルタと `isCommandPaletteShortcutHidden` 判定を共通評価へ統合。

### Phase 4: 実行経路の最終ガード統一

- `ApplyCanvasCommands` の `supportedIn(mode)` 経路と `KeymapExecutionPolicyResolver` を整合。
- 同一入力に対して UIで拒否された場合と実行時拒否結果が一致することを担保。

### Phase 5: テスト整備

- Domain 単体テスト
  - 条件 DSL の真理値評価テスト
  - 主要条件（area/node/edge、editing mode、text editing）の組合せテスト
- Adapter/UseCase 回帰テスト
  - `CanvasViewHotkeyAreaTargetPolicyTests` の期待結果を新条件評価へマッピング。
  - Command Palette フィルタの可否を context で検証。
  - `swift test` を通して既存テスト回帰が増えないことを確認。

### Phase 6: 収束

- 分散ガード関数の削除/非推奨化。
- ロジック重複を減らし、条件の単一発火点を明確にする。
- 変更履歴を `docs/specs/domain.md` と本計画に反映。

## 6. 受け入れ条件

- 挙動を変えずに、keymap の有効/無効判定が宣言的に確認できる。
- 同じ条件を以下で一貫して評価できる。
  - key capture 判定
  - command palette の表示有無
  - 実行可否の最終ガード
- 新規条件追加時は `KeymapExecutionCondition` の追加 + catalog 条件付与 + 対応テスト追加のみで対応可能。
- `swift build` / `swift test` / `./scripts/lint_and_format.sh` が通る。

## 7. リスクと対処

- Domain と UI の責務境界が曖昧化しやすい。
  - 対処: Context は `Context snapshot` として最小化し、取得元を一か所にする。
- 条件 DSL が複雑化。
  - 対処: 将来必要な条件だけを追加し、同値判定は小さな合成関数で分解。
- 既存挙動の同値確認。
  - 対処: まず `always` デフォルトで段階導入し、既存テストを赤化しないことを確認しつつ段階的に置換。
