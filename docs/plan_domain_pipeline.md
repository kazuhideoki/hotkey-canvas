# Plan: Domain再設計とApplication Coordinatorパイプライン

## 1. 目的と適用範囲

- 目的:
  - 機能拡張時の変更波及を制御しやすくする。
  - 再計算責務を明確化し、保守性と検証容易性を上げる。
  - 同一入力に対して同一最終状態へ収束する設計（決定性・冪等性）を強化する。
- 適用範囲:
  - `ApplyCanvasCommandsUseCase` のコマンド適用フロー。
  - `TreeLayout` / `AreaLayout` / `Focus` に関わるDomainサービス。
  - Viewport制御の意図生成（UI実装そのものは対象外）。

## 2. 現状（コード事実）

### 2.1 変更適用の中心

- `Sources/Application/UseCase/ApplyCanvasCommandsUseCase.swift`
  - `apply(commands:)` でコマンド列を順次適用し、Undo/Redoを管理。
- `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+CommandDispatch.swift`
  - `CanvasCommand` を各ハンドラへ分岐。

### 2.2 コマンドごとの再計算実態

| Command             | 主な変更                          | 再計算                                                       |
| ------------------- | --------------------------------- | ------------------------------------------------------------ |
| `addNode`           | ノード追加                        | `resolveAreaOverlaps`                                        |
| `addChildNode`      | ノード追加 + parentChild edge追加 | `relayoutParentChildTrees` -> `resolveAreaOverlaps`          |
| `addSiblingNode`    | ノード追加 + parentChild edge追加 | `relayoutParentChildTrees` -> `resolveAreaOverlaps`          |
| `moveNode`          | 階層/順序変更 + 座標調整          | `relayoutParentChildTrees` -> `resolveAreaOverlaps`          |
| `deleteFocusedNode` | 部分木削除 + フォーカス再決定     | `relayoutParentChildTrees` -> 条件付き `resolveAreaOverlaps` |
| `setNodeText`       | テキスト/高さ変更                 | `relayoutParentChildTrees` -> `resolveAreaOverlaps`          |
| `moveFocus`         | フォーカスのみ変更                | レイアウト再計算なし                                         |

### 2.3 DomainサービスとViewport現状

- Domain:
  - `CanvasGraphCRUDService`
  - `CanvasTreeLayoutService`
  - `CanvasAreaLayoutService`
  - `CanvasFocusNavigationService`
- Viewport:
  - `CanvasView` 側で `focusedNodeID` 変化に応じて手動パンをリセット。
  - フォーカス中心オフセットは `CanvasView+Behaviors` で算出。

## 3. 課題整理

- 変更処理と再計算処理が同一ハンドラに混在し、責務が分離されていない。
- 再計算順序（Tree -> Area など）がハンドラごとに分散し、順序の一貫性確認が難しい。
- Viewportの振る舞いがUI側イベント処理に寄っており、アプリケーション判断として追跡しづらい。
- 決定性・冪等性をステージ単位で保証する仕様/テストが不足している。

## 4. 採用方針

- パイプライン方式は **Application Coordinator** を採用する。
- 責務分割:
  - Domain: 純粋な状態変換（Graph更新、TreeLayout、AreaLayout、Focus計算）。
  - Application: ステージ実行順制御、実行条件判定、結果統合（`PipelineResult`）。
  - InterfaceAdapters: `ViewportIntent` の具体的なUI反映。

## 5. 目標パイプライン設計

### 5.1 入出力モデル

- コマンドハンドラは `CanvasMutationResult` を返す。
  - `graphAfterMutation`
  - `effects`（例: `affectsHierarchy`, `affectsNodeGeometry`, `affectsAreaPlacement`, `affectsFocus`）
- Coordinatorは `PipelineResult` を返す。
  - `graph`
  - `viewportIntent`

### 5.2 ステージ順序（固定）

1. Mutation Stage（コマンド本体の変更）
2. Tree Layout Stage（必要時）
3. Area Layout Stage（必要時）
4. Focus Normalization Stage（必要時）
5. Viewport Intent Stage（必要時）

※ 「途中段から開始しても最終段まで進む」をルール化する。

### 5.3 冪等性・決定性ルール

- 各ステージは pure function を維持する。
- 同一入力に対して同一出力（順序・epsilon含む）を保証する。
- ステージ単体で `stage(stage(state)) == stage(state)` を満たす。
- 非決定要素（ID生成など）は Service内で生成せず、Applicationから注入する。
- `Area Layout Stage` は「停止保証」と「非重なり達成保証」を満たす実装に限定する。

## 6. Domain再設計案

- D1: Graph Mutation Domain
  - ノード/エッジ/フォーカス更新と不変条件検証。
- D2: Tree Layout Domain
  - 親子構造の再配置。
- D3: Area Collision Domain
  - parentChild連結成分の衝突解消。
- D4: Focus Navigation Domain
  - 方向移動とフォーカス正規化。
- A1: Viewport Policy（Application）
  - DomainへUI依存を持ち込まず、`ViewportIntent` はApplication DTOとして扱う。

## 7. 実施手順と各フェーズの決定ポイント

### フェーズ1: 仕様固定の土台作成（挙動は変えない）

- 目的:
  - 現行挙動をテストで固定し、以降の段階的移行での回帰検知を可能にする。
  - `effects` とステージ実行条件の判定基準を明文化する。
- このフェーズで決める仕様:
  - `effects` の最小集合と各コマンドへの割り当て方針。
  - 決定性確認の比較単位（`CanvasState` 全体、または対象サブ構造単位）。
- 生成物:
  - コマンドごとの `effects` 判定表。
  - ステージ実行条件表（Tree/Area/Focus/Viewport）。
  - 現行挙動を固定する Characterization tests。
- 実装方針:
  - コード変更は最小限とし、主にテストと仕様表の追加を行う。
  - 既存実装の実行経路は変更しない。
- 完了条件:
  - 主要コマンドの期待挙動がテストで固定されている。
  - `swift test` が通り、現行仕様のまま動作する。

### フェーズ2: Coordinator骨格導入（接続は安全モード）

- 目的:
  - パイプライン実行順を集約する受け皿を先に導入し、段階移行できる構造を作る。
- このフェーズで決める仕様:
  - Stage間の入出力契約（`CanvasMutationResult`, `PipelineResult`）の型境界。
  - 旧経路と新経路の差分検知方法（テスト比較、必要に応じた実行時検知）。
- 生成物:
  - `Application/Coordinator` のパイプライン骨格。
  - Stage I/O DTOの初版。
  - 旧経路との比較を行う検証コードまたはテスト。
- 実装方針:
  - 実処理は従来経路を維持し、新骨格は比較/準備用途として導入する。
  - 新骨格導入で外部仕様を変更しない。
- 完了条件:
  - 新骨格がビルド対象に統合されている。
  - `swift test` で既存仕様との差分がないことを確認できる。

### フェーズ3: Mutation -> Tree -> Area の段階移管

- 目的:
  - コマンド変更処理と再計算処理の責務を分離し、実行順をCoordinatorへ一元化する。
- このフェーズで決める仕様:
  - コマンドごとの移管順序（低リスクコマンドから順次）。
  - `effects` と Tree/Area実行条件の最終対応。
  - Area再計算の適用条件（常時/条件付き）と停止保証の扱い。
- 生成物:
  - 各コマンドハンドラの `CanvasMutationResult` 返却化。
  - Coordinatorによる Mutation -> Tree -> Area 実行実装。
  - 冪等性テスト（`stage(stage(x)) == stage(x)`）と回帰テスト。
- 実装方針:
  - 移管対象を小さく区切り、1コマンド群ごとにテストで挙動一致を確認する。
  - 段階移管中も常に動作可能な状態を維持する。
- 完了条件:
  - 主要コマンドが新パイプライン経由で実行される。
  - `swift test` で既存期待との整合が取れている。

### フェーズ4: Focus/Viewport Intent統合と旧経路整理

- 目的:
  - フォーカス正規化とViewport意図生成をCoordinatorに統合し、責務分散を解消する。
- このフェーズで決める仕様:
  - `ViewportIntent` をApplication DTOとして確定する境界。
  - 旧UI側制御ロジックの撤去タイミングと責務移管範囲。
- 生成物:
  - Focus Normalization Stage / Viewport Intent Stage の本実装。
  - 旧分散ロジックの撤去または無効化。
  - `docs/domain.md` と本計画書の整合更新。
- 実装方針:
  - 旧経路削除はテスト整備後に限定し、段階的に切り替える。
  - Undo/Redoと決定性テストを維持しながら最終統合する。
- 完了条件:
  - 再計算順序と実行条件がCoordinator 1箇所で追跡できる。
  - `swift build`、`scripts/lint_and_format.sh`、`swift test` が通る。

## 8. 完了条件

- 再計算順序がCoordinatorの1箇所に定義されている。
- `effects` と実行ステージの対応が主要コマンドで一致している。
- 冪等性/決定性/UndoRedoのテストが通る。
- 収束保証テスト（停止・非重なり達成・再適用不変）が通る。
- `docs/domain.md` が再設計後の責務を反映している。
