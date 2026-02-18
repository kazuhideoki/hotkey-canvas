# HotkeyCanvas ドメインドキュメント

## 1. ドキュメントの目的

- `Sources/Domain/` の責務をドメイン単位で整理し、実装時の判断基準を明確にする。
- Domain の構造、サービス責務、利用状況、不変条件をまとめ、変更時の影響範囲を追跡しやすくする。
- Domain テストと Application/InterfaceAdapters の利用実態を対応づけ、仕様と実装のずれを防ぐ。

## 2. 対象範囲

- 本書は `Sources/Domain/` の型・サービスを主対象とする。
- 利用状況は `Sources/Application/` と `Sources/InterfaceAdapters/` の主要な呼び出し箇所まで扱う。
- 更新ルールは `AGENTS.md` に従う。

## 3. ドメイン一覧（索引）

| ID | ドメイン名 | 主な型/サービス |
| --- | --- | --- |
| D1 | キャンバスグラフ編集 | `CanvasGraph`, `CanvasNode`, `CanvasEdge`, `CanvasCommand`, `CanvasGraphCRUDService`, `CanvasGraphError` |
| D2 | フォーカス移動 | `CanvasFocusDirection`, `CanvasFocusNavigationService` |
| D3 | エリアレイアウト | `CanvasNodeArea`, `CanvasRect`, `CanvasTranslation`, `CanvasAreaLayoutService` |
| D4 | ツリーレイアウト | `CanvasTreeLayoutService` |
| D5 | ショートカットカタログ | `CanvasShortcutDefinition`, `CanvasShortcutGesture`, `CanvasShortcutAction`, `CanvasShortcutCatalogService`, `CanvasShortcutCatalogError` |

### D5 追加仕様（ズームショートカット）

- `CanvasShortcutAction` に `zoomIn` / `zoomOut` を追加した。
- `CanvasShortcutCatalogService` の標準定義に以下を追加した。
- `Command + +`（`Command + Shift + =` / `Command + Shift + ;` / `Command + +` 記号入力）: `zoomIn`
- `Command + =`: `zoomIn`
- `Command + -`: `zoomOut`
- 利用先:
- `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`（`zoomAction(_:)`）
- `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView.swift`（キー入力時の段階ズーム適用）
- `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView+CommandPalette.swift`（コマンドパレットからのズーム実行）

## 4. 各ドメイン詳細

### D1. キャンバスグラフ編集ドメイン

#### 構造

- 集約
  - `CanvasGraph`: ノード/エッジ/フォーカスを保持する不変スナップショット。
- エンティティ/値オブジェクト
  - `CanvasNode`, `CanvasNodeID`, `CanvasNodeKind`, `CanvasBounds`
  - `CanvasEdge`, `CanvasEdgeID`, `CanvasEdgeRelationType`
- コマンド
  - `CanvasCommand`
  - `CanvasNodeMoveDirection`
  - `CanvasSiblingNodePosition`
  - `CanvasCommand.centerFocusedNode`
- エラー
  - `CanvasGraphError`
- サービス
  - `CanvasGraphCRUDService`

#### サービス詳細

`CanvasGraphCRUDService` はグラフ編集の純粋 CRUD を提供する。

| メソッド | 責務 |
| --- | --- |
| `createNode(_:in:)` | ノードを追加し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |
| `readNode(id:in:)` | ノードを参照する。 |
| `updateNode(_:in:)` | 既存ノードを置換し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |
| `deleteNode(id:in:)` | ノードを削除し、接続エッジも同時に除去する。削除対象がフォーカス中なら `focusedNodeID` を `nil` にする。返却は `Result<CanvasGraph, CanvasGraphError>`。 |
| `createEdge(_:in:)` | エッジを追加し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |
| `readEdge(id:in:)` | エッジを参照する。 |
| `updateEdge(_:in:)` | 既存エッジを置換し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |
| `deleteEdge(id:in:)` | エッジを削除し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |

#### 利用状況（どこから使われるか）

- Application ユースケース
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddChildNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddSiblingNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+DeleteFocusedNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+MoveNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SetNodeText.swift`
- 入力境界/コマンド流入
  - `Sources/Application/Port/Input/CanvasEditingInputPort.swift`
  - `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`
  - `Sources/InterfaceAdapters/Output/ViewModel/CanvasViewModel.swift`
- 主要テスト
  - `Tests/DomainTests/CanvasGraphCRUDServiceTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCase/*`
  - `Tests/InterfaceAdaptersTests/CanvasViewModelTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - ノード ID は空文字を許容しない。
  - ノードの `width` / `height` は正値である必要がある。
  - エッジ ID は空文字を許容しない。
  - エッジの `fromNodeID` / `toNodeID` はグラフ内に存在する必要がある。
  - ノード/エッジの ID 重複は許容しない。
- エラー（`CanvasGraphError`）
  - `invalidNodeID`
  - `invalidEdgeID`
  - `invalidNodeBounds`
  - `nodeAlreadyExists(CanvasNodeID)`
  - `nodeNotFound(CanvasNodeID)`
  - `edgeAlreadyExists(CanvasEdgeID)`
  - `edgeNotFound(CanvasEdgeID)`
  - `edgeEndpointNotFound(CanvasNodeID)`

### D2. フォーカス移動ドメイン

#### 構造

- 入力値
  - `CanvasFocusDirection`（`up/down/left/right`）
- 参照モデル
  - `CanvasGraph`, `CanvasNode`, `CanvasBounds`
- サービス
  - `CanvasFocusNavigationService`

#### サービス詳細

`CanvasFocusNavigationService` は方向キー入力に対する次フォーカス決定を担当する。

| メソッド | 責務 |
| --- | --- |
| `nextFocusedNodeID(in:moving:)` | 現在フォーカス位置と移動方向から、次にフォーカスすべき `CanvasNodeID` を決定する。 |

選択ロジックの要点:

- 候補ノードは方向軸の前方（主軸距離 > 0）のみ対象。
- 主軸距離・副軸ずれ・角度ペナルティでスコアリング。
- 副軸ずれが小さい候補群を優先し、同点時は距離・ID で決定して決定性を担保。
- 空グラフでは `nil` を返し、候補なしでは現在フォーカスを維持する。

#### 利用状況（どこから使われるか）

- Application ユースケース
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+MoveFocus.swift`
  - `Sources/Application/Coordinator/CanvasCommandPipelineCoordinator.swift`
    - `needsFocusNormalization` が `true` のときに Focus Normalization Stage が実行される。
    - `focusedNodeID` が無効な場合は `y -> x -> id` 順で先頭ノードへ正規化する。
- コマンド発行
  - `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`（矢印キー -> `.moveFocus`、`cmd+矢印キー` -> `.moveNode`）
- 主要テスト
  - `Tests/DomainTests/CanvasFocusNavigationServiceTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCase/ApplyCanvasCommandsUseCase+MoveFocusTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - ノード列の並びは `y -> x -> id` で決定的に処理する。
  - `focusedNodeID` が不正な場合はソート先頭ノードを基準にする。
  - 候補が無いときは現在フォーカスを返す（空グラフを除く）。
- エラー
  - ドメインエラー型は持たず、`throws` しない。

### D3. エリアレイアウトドメイン

#### 構造

- モデル
  - `CanvasNodeArea`: 親子接続成分をひとまとまりの領域として表現する。
  - `CanvasAreaShapeKind`: 領域形状の生成戦略（矩形/凸包）を表現する。
  - `CanvasAreaShape`: 領域の外周形状（矩形/凸包頂点列）を表現する。
  - `CanvasPoint`: 凸包頂点や投影計算に使う 2D 座標値オブジェクト。
  - `CanvasRect`: 軸平行矩形の幾何計算を担う。
  - `CanvasTranslation`: 2D 平行移動量。
- 参照契約
  - `CanvasEdgeRelationType.parentChild` を接続判定に使用する。
- サービス
  - `CanvasAreaLayoutService`

#### サービス詳細

`CanvasAreaLayoutService` は親子構造を保ったレイアウト領域抽出と衝突解消を担当する。

| メソッド | 責務 |
| --- | --- |
| `makeParentChildAreas(in:shapeKind:)` | `parentChild` エッジを無向辺として連結成分を作り、指定戦略で領域形状（矩形/凸包）を構築して返す。 |
| `resolveOverlaps(areas:seedAreaID:minimumSpacing:maxIterations:)` | seed 領域を起点に衝突を伝播解消し、領域ごとの移動量を返す。 |

アルゴリズム要点:

- `makeParentChildAreas(in:)`
  - ノード ID 昇順で探索し、BFS で連結成分を抽出。
  - ノードが存在しないエッジ終端は無視。
  - 領域 ID は成分内の最小ノード ID を代表値として使う。
  - `shapeKind` が `.convexHull` の場合は、成分内ノード矩形の四隅点から凸包を生成して `CanvasNodeArea.shape` に保持する（退化ケースは矩形へフォールバック）。
- `resolveOverlaps(...)`
  - 初期衝突では seed 領域と最初の衝突領域を半分ずつ移動。
  - その後はキュー駆動で衝突先を順次押し出す。
  - 矩形同士は高速な矩形交差判定を使い、凸包を含む場合は SAT（分離軸定理）で衝突判定する。
  - 中心差分ベクトルを使って押し出し軸を決定し、移動方向は上下左右の4方向に限定する（`|dx| >= |dy|` なら X 軸、そうでなければ Y 軸）。
  - 同一中心時は ID 順に tie-break し、決定性を維持。
  - `numericEpsilon` 未満の移動は無効として切り捨てる。

#### 利用状況（どこから使われるか）

- Application Coordinator
  - `Sources/Application/Coordinator/CanvasCommandPipelineCoordinator.swift`
    - `runAreaLayoutStage(on:seedNodeID:)`
- Application 共有ヘルパー（配置候補計算）
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SharedHelpers+Graph.swift`
    - `parentChildArea(...)`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SharedHelpers.swift`
    - `addNode` の初期配置で最下エリアとエリア間隔を参照し、追加直後からエリア干渉しない候補座標を算出する。
- 幾何モデルの利用
  - `Sources/InterfaceAdapters/Output/SwiftUI/CanvasContentBoundsCalculator.swift`（`CanvasRect`）
- 主要テスト
  - `Tests/DomainTests/CanvasAreaLayoutServiceTests.swift`
  - `Tests/DomainTests/CanvasRectTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCase/ApplyCanvasCommandsUseCase+AddNodeTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCase/ApplyCanvasCommandsUseCase+AddChildNodeTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCase/ApplyCanvasCommandsUseCase+AddSiblingNodeTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - `minimumSpacing` は 0 未満を許容せず 0 に丸める。
  - `maxIterations <= 0` または領域数 1 以下の場合は移動なし。
  - `seedAreaID` が領域に存在しない場合は移動なし。
  - 返却値には非ゼロ移動のみ含める。
- エラー
  - ドメインエラー型は持たず、`throws` しない。

### D4. ツリーレイアウトドメイン

#### 構造

- 参照モデル
  - `CanvasGraph`, `CanvasNode`, `CanvasBounds`
  - `CanvasEdgeRelationType.parentChild`
- サービス
  - `CanvasTreeLayoutService`

#### サービス詳細

`CanvasTreeLayoutService` は親子ツリー全体の再配置を担当する。

| メソッド | 責務 |
| --- | --- |
| `relayoutParentChildTrees(in:verticalSpacing:horizontalSpacing:rootSpacing:)` | 親子エッジで接続されたノード群を上下対称で再配置し、再計算後の `CanvasBounds` を返す。 |

アルゴリズム要点:

- `parentChild` エッジのみを対象に連結成分を作る。
- 子ノードの並びは `y -> x -> id` で決定し、途中挿入時も順序を保持する。
- 子サブツリーを縦方向に積み上げ、親ノードを子クラスタの中心に配置する。
- 子ノードの X は `parent.width + horizontalSpacing` で親から右へ進める。
- ルートノードは元の座標をアンカーとして、再配置による急激なジャンプを抑える。
- 循環参照などで根が取れない成分は 1 本の親リンクを外して決定的に解決する。

#### 利用状況（どこから使われるか）

- Application Coordinator
  - `Sources/Application/Coordinator/CanvasCommandPipelineCoordinator.swift`
    - `runTreeLayoutStage(on:)`
- 主要テスト
  - `Tests/DomainTests/CanvasTreeLayoutServiceTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - `verticalSpacing` / `horizontalSpacing` / `rootSpacing` は 0 未満を許容せず 0 に丸める。
  - `parentChild` エッジが存在しない場合は空の更新結果を返す。
  - 返却値は親子接続成分に含まれるノードのみを対象とする。
  - 同一入力に対して決定的な結果を返す（順序 tie-break を含む）。
- エラー
  - ドメインエラー型は持たず、`throws` しない。

## 5. Application パイプライン連携（Phase4）

- 対象
  - `Sources/Application/Coordinator/CanvasCommandPipelineCoordinator.swift`
  - `Sources/Application/DTO/CanvasMutationEffects.swift`
  - `Sources/Application/DTO/CanvasViewportIntent.swift`
- ステージ順序（固定）
  - Mutation -> Tree Layout -> Area Layout -> Focus Normalization -> Viewport Intent
- 実行条件
  - Tree: `didMutateGraph && needsTreeLayout`
  - Area: `didMutateGraph && needsAreaLayout`
  - Focus: `didMutateGraph && needsFocusNormalization`
  - Viewport Intent: `centerFocusedNode` コマンド時は `resetManualPanOffset`
- 境界責務
  - Domain は純粋状態変換のみを担当する。
  - Application はステージ実行順と `CanvasViewportIntent` 生成を担当する。
  - InterfaceAdapters は `CanvasViewportIntent` を UI 状態へ反映し、表示ルール（初期中央化・画面外補正）を担う。

### D5. ショートカットカタログドメイン

#### 構造

- 値オブジェクト
  - `CanvasShortcutID`
  - `CanvasShortcutKey`
  - `CanvasShortcutModifiers`
  - `CanvasShortcutGesture`
- モデル
  - `CanvasShortcutDefinition`
- アクション
  - `CanvasShortcutAction`（`apply(commands:)` / `undo` / `redo` / `openCommandPalette`）
- エラー
  - `CanvasShortcutCatalogError`
- サービス
  - `CanvasShortcutCatalogService`

#### サービス詳細

`CanvasShortcutCatalogService` はショートカット定義の単一情報源を提供する。

| メソッド | 責務 |
| --- | --- |
| `defaultDefinitions()` | 静的に定義された標準ショートカット一覧を返す。 |
| `resolveAction(for:)` | `CanvasShortcutGesture` から実行アクションを解決する。 |
| `commandPaletteDefinitions()` | コマンドパレットに表示すべきショートカット定義のみ返す。 |
| `validate(definitions:)` | ID 重複・ジェスチャ重複・空文字項目を検証し、`Result<Void, CanvasShortcutCatalogError>` を返す。 |

#### 利用状況（どこから使われるか）

- 入力変換
  - `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`
    - `NSEvent` を `CanvasShortcutGesture` に正規化し、`resolveAction(for:)` で解決する。
- UI 表示
  - `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView.swift`
    - `commandPaletteDefinitions()` の結果をコマンドパレット一覧表示に使用する。
- 主要テスト
  - `Tests/DomainTests/CanvasShortcutCatalogServiceTests.swift`
  - `Tests/InterfaceAdaptersTests/CanvasHotkeyTranslatorTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - `CanvasShortcutID` は空文字（空白のみを含む）を許容しない。
  - `name` と `shortcutLabel` は空文字（空白のみを含む）を許容しない。
  - `searchTokens` に空文字（空白のみを含む）を含めない。
  - 同一カタログ内で `CanvasShortcutID` は一意である。
  - 同一カタログ内で `CanvasShortcutGesture` は一意である。
- エラー（`CanvasShortcutCatalogError`）
  - `emptyID(CanvasShortcutID)`
  - `emptyName(CanvasShortcutID)`
  - `emptyShortcutLabel(CanvasShortcutID)`
  - `emptySearchToken(CanvasShortcutID)`
  - `duplicateID(CanvasShortcutID)`
  - `duplicateGesture(CanvasShortcutGesture)`

## 5. ドメイン間の関係（依存・データ受け渡し）

1. `CanvasHotkeyTranslator` がキーイベントを `CanvasShortcutGesture` に正規化する。
2. `CanvasShortcutCatalogService.resolveAction(for:)` がジェスチャからアクションを解決する。
3. `CanvasShortcutAction.apply(commands:)` の場合のみ `ApplyCanvasCommandsUseCase` がコマンドをディスパッチする。
4. コマンド種別ごとに Domain サービスを利用する。
   - 編集: `CanvasGraphCRUDService`
   - フォーカス: `CanvasFocusNavigationService`
   - ツリー再レイアウト: `CanvasTreeLayoutService`
   - エリア衝突解消: `CanvasAreaLayoutService`
5. 生成された `CanvasGraph` を `ApplyResult` 経由で ViewModel に返し、表示状態を更新する。

共通契約:

- `CanvasEdgeRelationType.parentChild` は、子孫探索・ツリー再配置・エリア分割/衝突解消で共有される。
- `CanvasGraph` は Application と InterfaceAdapters 間の共通スナップショットとして扱う。
- Domain サービスは `throw` せず、失敗はドメイン固有エラーの `Result` で返す。

## 6. 変更履歴

- 2026-02-15: 初版作成。
- 2026-02-15: `CanvasTreeLayoutService` を追加し、親子ツリー再配置の利用箇所と不変条件を追記。
- 2026-02-15: `CanvasCommand.moveNode` と `CanvasNodeMoveDirection` を追加し、`cmd+矢印キー` のネスト移動利用箇所を追記。
- 2026-02-15: `CanvasTreeLayoutService` の実装を `CanvasTreeLayoutService+Relayout.swift` と `CanvasTreeLayoutService+RelayoutInternals.swift` に分割（挙動変更なし）。
- 2026-02-15: `moveNode(.left)` の挙動を変更し、トップレベルノードの子からルート親方向への昇格を抑止するガードを追加。
- 2026-02-16: `CanvasShortcutCatalogService` とショートカット関連モデルを追加し、ホットキー解決とコマンドパレット一覧の情報源をドメインで統一。
- 2026-02-16: Domain サービスの失敗表現を `throw` から `Result<..., 各DomainError>` に統一し、Application 側は `.get()` で既存 `throws` 契約を維持。
- 2026-02-18: Viewport Intent の運用を更新し、Application から `.resetManualPanOffset` を生成しない仕様へ変更（初期中央化/画面外補正は `CanvasView` の表示ルールで実施）。
- 2026-02-18: `ctrl+l` の `centerFocusedNode` コマンドを追加し、`apply` フローで `resetManualPanOffset` を返却することで、現在フォーカスノードを画面中央へ再配置する。
