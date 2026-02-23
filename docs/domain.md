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
| D1 | キャンバスグラフ編集 | `CanvasGraph`, `CanvasNode`, `CanvasEdge`, `CanvasCommand`, `CanvasDefaultNodeDistance`, `CanvasGraphCRUDService`, `CanvasGraphError` |
| D2 | フォーカス移動と複数選択 | `CanvasFocusDirection`, `CanvasFocusNavigationService`, `CanvasSelectionService` |
| D3 | エリアレイアウト | `CanvasNodeArea`, `CanvasRect`, `CanvasTranslation`, `CanvasAreaLayoutService` |
| D4 | ツリーレイアウト | `CanvasTreeLayoutService` |
| D5 | ショートカットカタログ | `CanvasShortcutDefinition`, `CanvasShortcutGesture`, `CanvasShortcutAction`, `CanvasShortcutCatalogService` |
| D6 | 折りたたみ可視性 | `CanvasFoldedSubtreeVisibilityService` |
| D7 | エリアモード所属管理 | `CanvasAreaID`, `CanvasEditingMode`, `CanvasArea`, `CanvasAreaMembershipService`, `CanvasAreaPolicyError` |

### D5 追加仕様（ズーム/折りたたみ/接続ショートカット）

- `CanvasShortcutAction` に `zoomIn` / `zoomOut` / `beginConnectNodeSelection` を追加した。
- `CanvasShortcutCatalogService` の標準定義に以下を追加した。
- `Command + +`（`Command + Shift + =` / `Command + Shift + ;` / `Command + +` 記号入力）: `zoomIn`
- `Command + =`: `zoomIn`
- `Command + -`: `zoomOut`
- `Command + L`: `beginConnectNodeSelection`
- `Option + .`: `toggleFoldFocusedSubtree`
- `Command + Shift + ↑/↓/←/→`: `nudgeNode(.up/.down/.left/.right)`
- `Shift + ↑/↓/←/→`: `extendSelection(.up/.down/.left/.right)`
- `Command + C`: `copyFocusedSubtree`
- `Command + X`: `cutFocusedSubtree`
- `Command + V`: `pasteSubtreeAsChild`
- 利用先:
- `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`（`zoomAction(_:)` / `shouldBeginConnectNodeSelection(_:)`）
- `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView.swift`（キー入力時の段階ズーム適用）
- `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView+CommandPalette.swift`（コマンドパレットからのズーム実行）

## 4. 各ドメイン詳細

### D1. キャンバスグラフ編集ドメイン

#### 構造

- 集約
- `CanvasGraph`: ノード/エッジ/フォーカス/選択集合/折りたたみルートを保持する不変スナップショット。
- エンティティ/値オブジェクト
  - `CanvasNode`, `CanvasNodeID`, `CanvasNodeKind`, `CanvasBounds`（`CanvasNode.attachments` はノード内添付、`CanvasNode.markdownStyleEnabled` は確定描画時 Markdown スタイル適用可否）
  - `CanvasAttachment`, `CanvasAttachmentID`, `CanvasAttachmentKind`, `CanvasAttachmentPlacement`
  - `CanvasEdge`, `CanvasEdgeID`, `CanvasEdgeRelationType`
  - `CanvasDefaultNodeDistance`（既定ノード間距離。`treeHorizontal = 32`、`treeVertical = 24`、`diagramHorizontal = 220`、`diagramVertical = 220`）
- コマンド
  - `CanvasCommand`
  - `CanvasNodeMoveDirection`
  - `CanvasCommand.nudgeNode`
  - `CanvasCommand.connectNodes(fromNodeID:toNodeID:)`
  - `CanvasSiblingNodePosition`
  - `CanvasCommand.centerFocusedNode`
  - `CanvasCommand.toggleFoldFocusedSubtree`
  - `CanvasCommand.upsertNodeAttachment(nodeID:attachment:nodeHeight:)`
  - `CanvasCommand.copyFocusedSubtree`
  - `CanvasCommand.cutFocusedSubtree`
  - `CanvasCommand.pasteSubtreeAsChild`
  - `CanvasCommand.toggleFocusedNodeMarkdownStyle`
  - `CanvasCommand.alignParentNodesVertically`
  - `CanvasCommand.extendSelection`
- エラー
  - `CanvasGraphError`
- サービス
  - `CanvasGraphCRUDService`

#### サービス詳細

`CanvasGraphCRUDService` はグラフ編集の純粋 CRUD を提供する。

| メソッド | 責務 |
| --- | --- |
| `createNode(_:in:)` | ノードを追加し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |
| `updateNode(_:in:)` | 既存ノードを置換し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |
| `deleteNode(id:in:)` | ノードを削除し、接続エッジも同時に除去する。削除対象がフォーカス中なら `focusedNodeID` を `nil` にする。返却は `Result<CanvasGraph, CanvasGraphError>`。 |
| `createEdge(_:in:)` | エッジを追加し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |
| `deleteEdge(id:in:)` | エッジを削除し、`Result<CanvasGraph, CanvasGraphError>` を返す。 |

#### 利用状況（どこから使われるか）

- Application ユースケース
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddChildNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddSiblingNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+ConnectNodes.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+DeleteFocusedNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+CopyPasteSubtree.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+MoveNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SetNodeText.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+UpsertNodeAttachment.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+ToggleFocusedNodeMarkdownStyle.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AlignParentNodesVertically.swift`
- 入力境界/コマンド流入
  - `Sources/Application/Port/Input/CanvasEditingInputPort.swift`
  - `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`
  - `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView+CommandPalette.swift`
  - `Sources/InterfaceAdapters/Output/ViewModel/CanvasViewModel.swift`
- 主要テスト
  - `Tests/DomainTests/CanvasGraphCRUDServiceTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCase/*`
  - `Tests/InterfaceAdaptersTests/CanvasViewModelTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - ノード ID は空文字を許容しない。
  - ノードの `width` / `height` は正値である必要がある。
  - ノード添付は `attachments` の空配列で未設定を表し、ノード内で `CanvasAttachment.id` の重複を許容しない。
  - 画像添付 (`CanvasAttachmentKind.image`) は `filePath` の空文字を許容しない。
  - ノードの Markdown スタイル適用フラグは `Bool` で保持し、新規ノードは既定で `true`。
  - エッジ ID は空文字を許容しない。
  - エッジの `fromNodeID` / `toNodeID` はグラフ内に存在する必要がある。
  - ノード/エッジの ID 重複は許容しない。
- エラー（`CanvasGraphError`）
  - `invalidNodeID`
  - `invalidEdgeID`
  - `invalidNodeBounds`
  - `invalidAttachmentID`
  - `invalidAttachmentPayload`
  - `duplicateAttachmentID(CanvasAttachmentID)`
  - `nodeAlreadyExists(CanvasNodeID)`
  - `nodeNotFound(CanvasNodeID)`
  - `edgeAlreadyExists(CanvasEdgeID)`
  - `edgeNotFound(CanvasEdgeID)`
  - `edgeEndpointNotFound(CanvasNodeID)`

### D2. フォーカス移動と複数選択ドメイン

#### 構造

- 入力値
  - `CanvasFocusDirection`（`up/down/left/right`）
- 参照モデル
  - `CanvasGraph`, `CanvasNode`, `CanvasBounds`
- サービス
  - `CanvasFocusNavigationService`
  - `CanvasSelectionService`

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

`CanvasSelectionService` は複数選択状態の正規化を担当する。

| メソッド | 責務 |
| --- | --- |
| `normalizedSelectedNodeIDs(from:in:focusedNodeID:)` | 可視ノード以外を除外し、フォーカスノードを必ず選択集合へ含める。 |
| `normalizedSelectedNodeIDs(in:)` | `CanvasGraph` 内の `selectedNodeIDs` を正規化する。 |

#### 利用状況（どこから使われるか）

- Application ユースケース
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+MoveFocus.swift`
    - `moveFocus` はフォーカス移動時に選択集合を単一ノードへ置き換える。
    - `extendSelection` は `shift+矢印` 用にフォーカス移動先を選択集合へ追加する。
  - `Sources/Application/Coordinator/CanvasCommandPipelineCoordinator.swift`
    - `needsFocusNormalization` が `true` のときに Focus Normalization Stage が実行される。
    - `focusedNodeID` が無効な場合は `y -> x -> id` 順で先頭ノードへ正規化する。
    - グラフ更新後は Selection Normalization Stage で `selectedNodeIDs` を正規化する。
- コマンド発行
  - `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`（矢印キー -> `.moveFocus`、`shift+矢印キー` -> `.extendSelection`、`cmd+矢印キー` -> `.moveNode`、`cmd+shift+矢印キー` -> `.nudgeNode`）
  - `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView+CompositeMove.swift`（`cmd+矢印` の連続入力を合成し、`upLeft/upRight/downLeft/downRight` を `.moveNode` として適用）
- 主要テスト
  - `Tests/DomainTests/CanvasFocusNavigationServiceTests.swift`
  - `Tests/DomainTests/CanvasSelectionServiceTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCase/ApplyCanvasCommandsUseCase+MoveFocusTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - ノード列の並びは `y -> x -> id` で決定的に処理する。
  - `focusedNodeID` が不正な場合はソート先頭ノードを基準にする。
  - 候補が無いときは現在フォーカスを返す（空グラフを除く）。
  - `selectedNodeIDs` は可視ノードかつ既存ノードのみを保持する。
  - `focusedNodeID != nil` のとき、`selectedNodeIDs` は必ず `focusedNodeID` を含む。
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
- 既定引数は `CanvasDefaultNodeDistance` を参照し、`verticalSpacing = treeVertical`、`horizontalSpacing = treeHorizontal`、`rootSpacing = treeRootVertical` を採用する。

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
- サービス
  - `CanvasShortcutCatalogService`

#### サービス詳細

`CanvasShortcutCatalogService` はショートカット定義の単一情報源を提供する。

| メソッド | 責務 |
| --- | --- |
| `resolveAction(for:)` | `CanvasShortcutGesture` から実行アクションを解決する。 |
| `commandPaletteDefinitions()` | コマンドパレットに表示すべきショートカット定義のみ返す。 |

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
  - 標準ショートカット定義は実装内の静的配列で管理し、入力解決とコマンドパレット表示で共有する。
  - `Shift + 矢印` は `.extendSelection` に解決し、`moveFocus` と競合しない。
- エラー
  - ドメインエラー型は持たず、`throws` しない。

### D6. 折りたたみ可視性ドメイン

#### 構造

- 参照モデル
  - `CanvasGraph`
  - `CanvasEdgeRelationType.parentChild`
- サービス
  - `CanvasFoldedSubtreeVisibilityService`

#### サービス詳細

`CanvasFoldedSubtreeVisibilityService` は折りたたみ状態から可視ノード集合を導出する純粋計算を担当する。

| メソッド | 責務 |
| --- | --- |
| `descendantNodeIDs(of:in:)` | 親子エッジを辿って子孫ノード集合を返す。 |
| `hasDescendants(of:in:)` | 指定ノードが子孫を持つか判定する。 |
| `normalizedCollapsedRootNodeIDs(in:)` | 存在しないノードや葉ノードを折りたたみルート集合から除外する。 |
| `hiddenNodeIDs(in:)` | 折りたたみルート配下の子孫ノード集合を返す。 |
| `visibleNodeIDs(in:)` | 非表示ノードを除いた可視ノード集合を返す。 |
| `visibleGraph(from:)` | 可視ノード/可視エッジのみを持つ `CanvasGraph` を返す。 |

#### 利用状況（どこから使われるか）

- Application ユースケース
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+ToggleFoldFocusedSubtree.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+MoveFocus.swift`
- Application Coordinator
  - `Sources/Application/Coordinator/CanvasCommandPipelineCoordinator.swift`
    - グラフ更新後に折りたたみルート集合を正規化する。
    - Focus Normalization は可視グラフを基準に行う。
- InterfaceAdapters 出力
  - `Sources/InterfaceAdapters/Output/ViewModel/CanvasViewModel.swift`
    - 可視グラフのみを画面描画用 state として公開する。
- 主要テスト
  - `Tests/DomainTests/CanvasFoldedSubtreeVisibilityServiceTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCase/ApplyCanvasCommandsUseCase+ToggleFoldFocusedSubtreeTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - 折りたたみは「ルート自体は可視、子孫のみ非表示」で扱う。
  - 折りたたみルートは、存在するノードかつ子孫を持つノードのみ有効。
  - 可視グラフ上で無効なフォーカス ID は `nil` として扱う。
  - 可視グラフ上で `selectedNodeIDs` は可視集合へ正規化され、可視フォーカスを必ず含む。
- エラー
  - ドメインエラー型は持たず、`throws` しない。

### D7. エリアモード所属管理ドメイン

#### 構造

- モデル
  - `CanvasAreaID`
  - `CanvasEditingMode`（`tree` / `diagram`）
  - `CanvasArea`（`id`, `nodeIDs`, `editingMode`）
- エラー
  - `CanvasAreaPolicyError`
- サービス
  - `CanvasAreaMembershipService`

#### サービス詳細

`CanvasAreaMembershipService` はノード所属とモード境界の整合性を担保する純粋計算を担当する。

| メソッド | 責務 |
| --- | --- |
| `validate(in:)` | 「ノードはちょうど1エリアに所属」「エリアが存在しないノード参照を持たない」を検証する。 |
| `areaID(containing:in:)` | ノード所属エリアを解決する。 |
| `focusedAreaID(in:)` | フォーカスノード所属エリアを解決する。 |
| `area(withID:in:)` | エリアIDからエリア情報を取得する。 |
| `convertFocusedAreaMode(to:in:)` | フォーカスノード所属エリアの編集モードを変換する（同一モード指定は no-op 成功）。 |
| `createArea(id:mode:nodeIDs:in:)` | 新規エリアを作成する。 |
| `assign(nodeIDs:to:in:)` | ノード集合を指定エリアへ再所属させる。 |
| `remove(nodeIDs:in:)` | ノード集合を全エリア所属から除外する。 |

#### 利用状況（どこから使われるか）

- Application ユースケース
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+CommandDispatch.swift`
    - コマンド適用前に所属整合性検証と対象エリア解決を行う。
    - `convertFocusedAreaMode` / `createArea` / `assignNodesToArea` をエリア管理コマンドとして適用する。
    - Diagram エリアでは `addChildNode` を `addNode` へ正規化する。
    - Diagram エリアでは `connectNodes` を許可し、同一エリア内の既存ノード同士を `normal` エッジで接続する（自己接続・重複接続・跨ぎ接続は no-op）。
    - Diagram エリアでは `moveNode` を8方向移動として扱う。接続アンカーがある場合はアンカー基準でステップ距離（`CanvasDefaultNodeDistance` 横 `220`・縦 `220`）を決定し、候補位置がアンカー矩形と重なる場合は同方向に追加ステップして飛び越える。接続アンカーがない場合でも、フォーカスノード自身の寸法を基準に同じグリッド間隔で移動できる。
    - Diagram エリアで `moveNode` を適用した後は、同一エリア内ノード衝突も即時解消するために area layout を実行する。
    - Diagram エリアでは `nudgeNode` を座標微調整として扱い、既定ステップは `CanvasDefaultNodeDistance`（横 `220`・縦 `220`）を使う。
    - `alignParentNodesVertically` は Tree/Diagram の両モードで実行可能とし、フォーカス中エリア内の親ノード（エリア内で親子入辺を持たないノード）の `x` を最左ノード基準に揃える。整列時は親ノード配下サブツリーを一括で同じ `dx` 平行移動し、エリア内の相対位置を維持する。さらに整列後は親サブツリー同士の重なりを `y` 方向の平行移動で解消し、縦一列の `x` 基準を維持する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddNode.swift`
    - Diagram エリアでは `addNode` 実行時、フォーカスノードが存在する場合に `relationType = .normal` のエッジで新規ノードと接続する。
    - Diagram エリアで新規作成されるノードは、Tree ノード横幅（`220`）を一辺とする正方形で生成する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SetNodeText.swift`
    - Diagram エリアでは `setNodeText` 実行時に入力高さを採用せず、ノード寸法を Tree ノード横幅（`220`）の正方形へ正規化する。
  - `Sources/Application/Coordinator/CanvasCommandPipelineCoordinator.swift`
    - グラフ変更後に Diagram エリア所属ノードの寸法を Tree ノード横幅（`220`）正方形へ正規化し、`convertFocusedAreaMode` / `createArea` / `assignNodesToArea` 経由でも形状不変条件を維持する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddChildNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddSiblingNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+ConnectNodes.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+DeleteFocusedNode.swift`
    - `deleteFocusedNode` は複数選択時にフォーカス所属エリア内の選択ノードを削除対象へ昇格する。Tree では各選択ノードの subtree まで削除し、Diagram では選択ノード自体のみ削除する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+CopyPasteSubtree.swift`
    - 追加/削除時の所属更新を行う。
- 主要テスト
  - `Tests/DomainTests/CanvasAreaMembershipServiceTests.swift`
  - `Tests/ApplicationTests/ApplyCanvasCommandsUseCaseAreaPolicyTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - ノードが1件以上ある場合、エリア定義は空を許容しない。
  - 各ノードはちょうど1つのエリアに所属する。
  - エリア所属ノードは必ず `CanvasGraph.nodesByID` に存在する。
  - エリア再編（`createArea` / `assign`）後、エッジは必ず同一エリア内に閉じる（跨ぎエッジ禁止）。
  - フォーカス基準ディスパッチ時、フォーカスノード未解決はエラーとする。
- エラー（`CanvasAreaPolicyError`）
  - `areaDataMissing`
  - `focusedNodeNotFound`
  - `focusedNodeNotAssignedToArea(CanvasNodeID)`
  - `nodeAssignedToMultipleAreas(CanvasNodeID)`
  - `nodeWithoutArea(CanvasNodeID)`
  - `areaContainsMissingNode(CanvasAreaID, CanvasNodeID)`
  - `areaNotFound(CanvasAreaID)`
  - `areaAlreadyExists(CanvasAreaID)`
  - `areaResolutionAmbiguousForAddNode`
  - `unsupportedCommandInMode(mode:command:)`
  - `crossAreaEdgeForbidden(CanvasEdgeID)`

## 5. ドメイン間の関係（依存・データ受け渡し）

1. `CanvasHotkeyTranslator` がキーイベントを `CanvasShortcutGesture` に正規化する。
2. `CanvasShortcutCatalogService.resolveAction(for:)` がジェスチャからアクションを解決する。
3. `CanvasShortcutAction.apply(commands:)` の場合のみ `ApplyCanvasCommandsUseCase` がコマンドをディスパッチする。
4. コマンド種別ごとに Domain サービスを利用する。
   - 編集: `CanvasGraphCRUDService`
   - フォーカス: `CanvasFocusNavigationService`
   - ツリー再レイアウト: `CanvasTreeLayoutService`
   - エリア衝突解消: `CanvasAreaLayoutService`
   - 折りたたみ可視性: `CanvasFoldedSubtreeVisibilityService`
   - エリア所属/モード解決: `CanvasAreaMembershipService`
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
- 2026-02-18: 未使用だった Domain 公開 API（`CanvasGraphCRUDService.readNode/readEdge/updateEdge`、`CanvasShortcutCatalogService.defaultDefinitions/validate`、`CanvasShortcutCatalogError`）を削除。
- 2026-02-19: `toggleFoldFocusedSubtree` コマンドと `Option + .` ショートカットを追加し、`CanvasFoldedSubtreeVisibilityService` で折りたたみ可視性の計算を Domain に集約。
- 2026-02-21: Diagram mode Phase1 基盤として `CanvasArea*` モデル、`CanvasAreaMembershipService`、`CanvasAreaPolicyError`、モード別コマンドディスパッチ境界を追加。
- 2026-02-21: Diagram mode Phase2 として、`createArea` / `assignNodesToArea` の Diagram 実行許可、`addNode` の複数エリア曖昧解決エラー、跨ぎエッジ禁止（`crossAreaEdgeForbidden`）の強制を追加。
- 2026-02-21: Diagram mode Phase3 として `convertFocusedAreaMode(to:)` を追加し、フォーカス基準のモード変換（同一モード no-op）と `Shift + Enter` モード選択導線を実装。
- 2026-02-22: `CanvasNode.imagePath` と `CanvasCommand.setNodeImage` を追加し、ノード上部画像の挿入/置換をドメイン編集コマンドとして扱う仕様を追記。
- 2026-02-22: `CanvasNode` 初期化時の `imagePath` を必須化し、ノード再構築時に画像パスを明示伝播することで、画像データ欠落をコンパイル時に検出できるようにした。
- 2026-02-22: Tree PhaseA として `copyFocusedSubtree` / `cutFocusedSubtree` / `pasteSubtreeAsChild` と `Command + C/X/V` を追加し、アプリ内コピー&ペーストを導入。
- 2026-02-22: Diagram mode の編集導線を更新し、`addChildNode` を Diagram では `addNode` として解釈する仕様を追加。
- 2026-02-22: Diagram mode の `addNode` を更新し、フォーカスノードが存在する場合は新規ノードを `normal` エッジで接続する仕様を追加。
- 2026-02-22: Diagram mode のノード寸法ルールを更新し、Tree ノード横幅（`220`）を一辺とする正方形へ統一（`addNode` / `setNodeText` / エリアモード変換・再所属後の正規化を含む）。
- 2026-02-22: `CanvasNode.markdownStyleEnabled` と `toggleFocusedNodeMarkdownStyle` コマンドを追加し、コマンドパレットからフォーカスノード単位で Markdown スタイル適用を切り替え可能にした。
- 2026-02-22: `CanvasNodeMoveDirection` を8方向（斜め4方向を追加）へ拡張し、Diagram mode では `moveNode` を接続アンカー基準の8方向スロット移動に変更した。微調整移動は `nudgeNode`（`cmd+shift+矢印`）として分離した。
- 2026-02-23: Diagram mode の `moveNode` を更新し、アンカー周囲の固定8スロット再配置ではなく、現在位置を基準にした連続グリッド移動へ変更。候補位置がアンカー矩形と重なる場合は同方向へ飛び越える仕様を追加した。
- 2026-02-22: `alignParentNodesVertically` コマンドを追加し、Command Palette からフォーカスエリア内の親ノードを最左基準で縦一列に整列できるようにした（Tree/Diagram 両対応）。
- 2026-02-22: `CanvasDefaultNodeDistance` を更新し、Tree/Diagram の既定ノード間距離（Tree: 横 `32` / 縦 `24`、Diagram: 横 `220` / 縦 `220`）を Domain で一元管理する仕様へ更新。
- 2026-02-22: 新規ウィンドウ起動時の初期ノード自動生成を廃止し、ノード未存在時は `Shift + Enter` と同一の Tree/Diagram モード選択導線から最初のノードを追加する仕様へ更新。
- 2026-02-22: 全ノード削除後に複数空エリアが残る状態でも、`Shift + Enter` のモード選択追加が失敗しないように、ノード未存在時は選択モードに合うエリアを優先解決（なければ新規作成）する仕様へ更新。
- 2026-02-23: `Shift + Enter` モード選択追加の empty graph 分岐を修正し、選択モードと不一致な `defaultTree` の誤優先を禁止。あわせて空グラフで area を事前作成した場合でも、履歴の `graphBeforeMutation` は必ず元グラフを保持して undo 整合性を維持するよう更新。
- 2026-02-23: `CanvasCommand.connectNodes` と `Command + L`（`beginConnectNodeSelection`）を追加し、Diagram エリアで既存ノード同士を接続できる操作導線を実装した。
- 2026-02-23: 画像専用の `CanvasNode.imagePath` と `CanvasCommand.setNodeImage` を廃止し、`CanvasAttachment` / `upsertNodeAttachment` に統合。ノード添付を将来拡張可能な複数要素として扱う仕様へ更新した。
- 2026-02-23: 複数選択の導入として `CanvasGraph.selectedNodeIDs`、`CanvasCommand.extendSelection`、`CanvasSelectionService` を追加。`Shift + 矢印` による選択拡張、パイプラインでの selection 正規化、表示側での複数選択ハイライト連携を追記した。
- 2026-02-23: `deleteFocusedNode` を拡張し、複数選択時はフォーカス所属エリア内の選択ノードを削除対象として扱う仕様を追加（Tree は subtree まで、Diagram は選択ノードのみ）。
