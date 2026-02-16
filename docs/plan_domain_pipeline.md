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

1. 仕様固定フェーズ
   - 実施:
     - コマンドごとの波及マトリクス（1->2->3->4）を確定。
     - 現挙動をテストで凍結。
   - 決定ポイント:
     - no-op条件をどこまで仕様化するか。
2. 影響モデル導入フェーズ
   - 実施:
     - `CanvasMutationEffects` / `CanvasMutationResult` 追加。
     - 各ハンドラは mutation のみ実施して effects を返却。
   - 決定ポイント:
     - `effects` の最小集合（冗長フラグを持たない）。
3. Coordinator導入フェーズ
   - 実施:
     - `PipelineCoordinator` 追加。
     - 既存 `relayoutParentChildTrees` / `resolveAreaOverlaps` 呼び出しを集約。
   - 決定ポイント:
     - Stage間DTOの責務境界。
4. 出力契約整理フェーズ
   - 実施:
     - `ApplyResult` に `viewportIntent` を追加。
     - Adapterで `viewportIntent` を解釈する。
   - 決定ポイント:
     - `viewportIntent` の種類と互換性方針。
5. 品質強化フェーズ
   - 実施:
     - 冪等性テスト、決定性テスト、Undo/Redo回帰テストを追加。
     - 収束保証テスト（停止・非重なり達成・再適用不変）を追加。
   - 決定ポイント:
     - epsilon比較基準と収束判定基準。
6. ドキュメント反映フェーズ
   - 実施:
     - `docs/domain.md` / `docs/architecture.md` を更新。
   - 決定ポイント:
     - 新しい責務説明の粒度統一。

※ 各フェーズ完了時にレビューを挟み、次フェーズへ進む。

## 8. 完了条件

- 再計算順序がCoordinatorの1箇所に定義されている。
- `effects` と実行ステージの対応が主要コマンドで一致している。
- 冪等性/決定性/UndoRedoのテストが通る。
- 収束保証テスト（停止・非重なり達成・再適用不変）が通る。
- `docs/domain.md` が再設計後の責務を反映している。
