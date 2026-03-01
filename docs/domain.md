# HotkeyCanvas ドメインドキュメント

## 1. ドキュメントの目的

- `Sources/Domain/` の責務をドメイン単位で整理し、実装時の判断基準を明確にする。
- Domain の構造、サービス責務、利用状況、不変条件をまとめ、変更時の影響範囲を追跡しやすくする。
- Domain テストと Application/InterfaceAdapters の利用実態を対応づけ、仕様と実装のずれを防ぐ。
- ドメイン構造の関係図は `docs/domain-er.md` を参照する。

## 2. 対象範囲

- 本書は `Sources/Domain/` の型・サービスを主対象とする。
- 利用状況は `Sources/Application/` と `Sources/InterfaceAdapters/` の主要な呼び出し箇所まで扱う。
- 更新ルールは `AGENTS.md` に従う。

## 3. ドメイン一覧（索引）

| ID | ドメイン名 | 主な型/サービス |
| --- | --- | --- |
| D1 | キャンバスグラフ編集 | `CanvasGraph`, `CanvasFocusedElement`, `CanvasEdgeFocus`, `CanvasNode`, `CanvasEdge`, `CanvasCommand`, `CanvasDefaultNodeDistance`, `CanvasGraphCRUDService`, `CanvasGraphError` |
| D2 | フォーカス移動と複数選択 | `CanvasFocusDirection`, `CanvasFocusNavigationService`, `CanvasSelectionService` |
| D3 | エリアレイアウト | `CanvasNodeArea`, `CanvasRect`, `CanvasTranslation`, `CanvasAreaLayoutService` |
| D4 | ツリーレイアウト | `CanvasTreeLayoutService` |
| D5 | ショートカットカタログ | `CanvasCommandPaletteLabel`, `CanvasShortcutDefinition`, `CanvasShortcutGesture`, `CanvasShortcutAction`, `CanvasShortcutCatalogService`, `KeymapShortcutScope`, `KeymapPrimitiveIntent`, `KeymapGlobalAction`, `KeymapResolvedRoute`, `KeymapIntentResolver` |
| D6 | 折りたたみ可視性 | `CanvasFoldedSubtreeVisibilityService` |
| D7 | エリアモード所属管理 | `CanvasAreaID`, `CanvasEditingMode`, `CanvasArea`, `CanvasAreaMembershipService`, `CanvasAreaPolicyError` |

### D5 追加仕様（ズーム/折りたたみ/接続/複製ショートカット）

- `CanvasShortcutAction` に `zoomIn` / `zoomOut` / `beginConnectNodeSelection` を追加した。
- `CanvasShortcutCatalogService` の標準定義に以下を追加した。
- `⌘+`（`⌘⇧=` / `⌘⇧;` / `⌘+` 記号入力）: `zoomIn`
- `⌘=`: `zoomIn`
- `⌘-`: `zoomOut`
- `⌘⌥+`（`⌘⌥=` / `⌘⌥⇧=` / `⌘⌥⇧;` / テンキー `+`）: `scaleSelectedNodes(.up)`
- `⌘⌥-`: `scaleSelectedNodes(.down)`
- `⌘L`: `beginConnectNodeSelection`
- `⌥.`: `toggleFoldFocusedSubtree`
- `⌘⇧↑/↓/←/→`: `nudgeNode(.up/.down/.left/.right)`
- `⇧↑/↓/←/→`: `extendSelection(.up/.down/.left/.right)`
- `⌘C`: `copySelectionOrFocusedSubtree`
- `⌘X`: `cutSelectionOrFocusedSubtree`
- `⌘V`: `pasteClipboardAtFocusedNode`
- `⌘D`: `duplicateSelectionAsSibling`
- 利用先:
- `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`（`zoomRouteByKeyCode(from:)` / `nodeScaleRouteByKeyCode(from:)`）
- `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView.swift`（キー入力時の段階ズーム適用）
- `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView+CommandPalette.swift`（コマンドパレットからのズーム実行）

### D5 追加仕様（Keymap Primitive Phase 1/2）

- Scope は `primitive` / `global` / `modal` の 3 種を固定する。
- `KeyTrigger -> Intent -> ContextAction` は `primitive` スコープでのみ適用する。
- `global` と `modal` は Intent 解決経路に混在させず、専用ルートで扱う。
- Intent 解決順は `User Override -> Context/Mode Override -> Intent Base Map` を仕様上の固定順とする。
- `search`（`cmd+f`）は当面 `global` として扱う。

### D5 追加仕様（Keymap Primitive Phase 3）

- Input Adapter の公開経路は `CanvasHotkeyTranslator.resolve(_:) -> KeymapResolvedRoute?` に一本化した。
- `KeymapIntentResolver` は既存ホットキーの現行セットを `global` または `primitive` として解決可能にした（`cmd+c/x/v` を含む）。
- Primitive Intent には既存コマンドを損失なく再構成できるよう、以下の情報を追加した。
  - `edit` の variant（copy/cut/paste/align）
  - `moveFocus` の方向
  - `moveNode` / `nudgeNode` の方向
- `transform` のうち `scaleSelectionUp` / `scaleSelectionDown` は実装済みとし、`CanvasCommand.scaleSelectedNodes(.up/.down)` へ解決する。
- `zoom` は既存挙動維持のため、`keyCode` 起点の互換解決（`cmd+shift+;`、テンキー `+` など）を維持する。
- 未実装 Intent（`output` / `export` / `import` / `transform.convertFocusedAreaMode`）は `KeymapContextAction.reportUnsupportedIntent` へ解決し、実行時は no-op 契約とする。

## 4. 各ドメイン詳細

### D1. キャンバスグラフ編集ドメイン

#### 構造

- 集約
- `CanvasGraph`: ノード/エッジ/フォーカス/選択集合/折りたたみルートを保持する不変スナップショット。
- エンティティ/値オブジェクト
  - `CanvasNode`, `CanvasNodeID`, `CanvasNodeKind`, `CanvasBounds`（`CanvasNode.attachments` はノード内添付、`CanvasNode.markdownStyleEnabled` は確定描画時 Markdown スタイル適用可否）
  - `CanvasAttachment`, `CanvasAttachmentID`, `CanvasAttachmentKind`, `CanvasAttachmentPlacement`
  - `CanvasEdge`, `CanvasEdgeID`, `CanvasEdgeRelationType`（`parentChild` エッジは `parentChildOrder` で兄弟順序を保持）
  - `CanvasFocusedElement`（`.node` / `.edge` の操作対象）
  - `CanvasEdgeFocus`（`edgeID` と `originNodeID` を保持する edge フォーカス情報）
  - `CanvasDefaultNodeDistance`（既定ノード間距離。`treeHorizontal = 32`、`treeVertical = 24`、`diagramHorizontal = 220`、`diagramVertical = 220`、画像添付時の Diagram ノード上限 `diagramImageMaxSide = 330`、Diagram ノード最小辺長 `diagramMinNodeSide = 110`、選択ノード拡縮ステップ `nodeScaleStepRatio = 0.1`）
- コマンド
  - `CanvasCommand`
  - `CanvasNodeMoveDirection`
  - `CanvasNodeScaleDirection`
  - `CanvasCommand.nudgeNode`
  - `CanvasCommand.scaleSelectedNodes`
  - `CanvasCommand.connectNodes(fromNodeID:toNodeID:)`
  - `CanvasSiblingNodePosition`
  - `CanvasCommand.centerFocusedNode`
  - `CanvasCommand.toggleFoldFocusedSubtree`
  - `CanvasCommand.upsertNodeAttachment(nodeID:attachment:nodeWidth:nodeHeight:)`
  - `CanvasCommand.copySelectionOrFocusedSubtree`
  - `CanvasCommand.cutSelectionOrFocusedSubtree`
  - `CanvasCommand.pasteClipboardAtFocusedNode`
  - `CanvasCommand.deleteSelectedOrFocusedEdges(focusedEdge:selectedEdgeIDs:)`
  - `CanvasCommand.duplicateSelectionAsSibling`
  - `CanvasCommand.toggleFocusedNodeMarkdownStyle`
  - `CanvasCommand.alignAllAreasVertically`
  - `CanvasCommand.extendSelection`
  - `CanvasCommand.focusNode(CanvasNodeID)`
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
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+DeleteSelectedOrFocusedEdges.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+CopyPasteSubtree.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+DuplicateSelectionAsSibling.swift`
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
  - `parentChildOrder` は `parentChild` エッジの兄弟順序を表す任意値で、未設定時は座標順フォールバックで決定する。
  - ノード/エッジの ID 重複は許容しない。
  - `CanvasGraph.focusedElement` は操作対象の種類を保持する。未指定時は `focusedNodeID` から `.node` を導出する。
  - `CanvasGraph.selectedEdgeIDs` は `focusedElement == .edge` のときにのみ意味を持ち、正規化時に `focused edge` を必ず含む。
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
| `nextFocusedEdgeID(in:from:moving:)` | 現在フォーカス edge と移動方向から、次にフォーカスすべき `CanvasEdgeID` を決定する。 |

選択ロジックの要点:

- 候補ノードは方向軸の前方（主軸距離 > 0）のみ対象。
- 主軸距離・副軸ずれ・角度ペナルティでスコアリング。
- 副軸ずれが小さい候補群を優先し、同点時は距離・ID で決定して決定性を担保。
- edge フォーカスでは、同一 endpoint ペア（無向・relationType 一致）の重複 edge がある場合、方向候補探索より先に重複束内を巡回する。
- edge の重複束判定は endpoint ペア基準で行い、中心座標一致のみでは巡回対象に含めない。
- 空グラフでは `nil` を返し、候補なしでは現在フォーカスを維持する。

`CanvasSelectionService` は複数選択状態の正規化を担当する。

| メソッド | 責務 |
| --- | --- |
| `normalizedSelectedNodeIDs(from:in:focusedNodeID:)` | 可視ノード以外を除外し、フォーカスノードを必ず選択集合へ含める。 |
| `normalizedSelectedNodeIDs(in:)` | `CanvasGraph` 内の `selectedNodeIDs` を正規化する。 |
| `normalizedSelectedEdgeIDs(from:in:focusedEdgeID:)` | 既存 edge 以外を除外し、フォーカス edge を必ず選択集合へ含める。 |
| `normalizedSelectedEdgeIDs(in:)` | `CanvasGraph` 内の `selectedEdgeIDs` を正規化する。 |

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
  - `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView+Search.swift`（`esc` で検索解除時に `.focusNode` を適用し、検索移動先ノードへフォーカス同期）
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
  - `selectedEdgeIDs` は既存 edge のみを保持する。
  - `focusedElement == .edge` のとき、`selectedEdgeIDs` は必ず `focused edge` を含む。
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
- 子ノードの並びは `parentChildOrder` を優先し、未設定時のみ `y -> x -> id` へフォールバックする。
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
  - Viewport Intent: 現状パイプラインステージでは自動生成しない。`centerFocusedNode` コマンド時のみ `ApplyCanvasCommandsUseCase.apply` が `resetManualPanOffset` を付与する。
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
  - `CanvasCommandPaletteLabel`
  - `CanvasCommandPaletteContext`
  - `CanvasCommandPaletteVisibility`
  - `CanvasShortcutDefinition`
  - `KeymapShortcutScope`
  - `KeymapPrimitiveIntent`
  - `KeymapGlobalAction`
  - `KeymapResolvedRoute`
- アクション
  - `CanvasShortcutAction`（既存経路の互換維持用）
- サービス
  - `CanvasShortcutCatalogService`
  - `KeymapIntentResolver`

#### サービス詳細

`CanvasShortcutCatalogService` はショートカット定義の単一情報源を提供する。

| メソッド | 責務 |
| --- | --- |
| `resolveAction(for:)` | `CanvasShortcutGesture` から実行アクションを解決する。 |
| `commandPaletteDefinitions()` | コマンドパレットに表示すべきショートカット定義のみ返す。 |
| `commandPaletteDefinitions(context:)` | フォーカス有無・編集モードを使って、実行不能な項目を非表示にした定義のみ返す。 |
| `KeymapIntentResolver.resolveRoute(for:)` | `CanvasShortcutGesture` を `primitive/global` の経路へ分類し、`primitive` のみ Intent を返す（非対応は `nil`）。`modal` は View の状態管理で扱う。 |

#### Primitive Intent 語彙（Phase 1 固定）

- `add`
- `edit`
- `delete`
- `toggleVisibility`
- `duplicate`
- `attach`
- `switchTargetKind`
- `moveFocus`
- `moveNode`
- `nudgeNode`
- `transform`
- `output`
- `export`
- `import`

補足:

- Intent は修飾キーを保持しない。
- 同一プリミティブ内の意味差分は Intent variant で扱う（例: `add` の追加位置差分）。

#### KeyTrigger 対応表（primitive 対象のみ）

| KeyTrigger | Primitive Intent |
| --- | --- |
| `enter` | `add(.primary)` |
| `opt+enter` | `add(.alternate)` |
| `cmd+enter` | `add(.hierarchical)` |
| `shift+enter` | `add(.modeSelect)` |
| `delete` | `delete` |
| `cmd+d` | `duplicate` |
| `arrow` | `moveFocus(.single)` |
| `shift+arrow` | `moveFocus(.extendSelection)` |
| `cmd+arrow` | `moveNode` |
| `cmd+shift+arrow` | `nudgeNode` |
| `opt+.` | `toggleVisibility` |
| `tab` | `switchTargetKind(.edge)` |

注記:
- `switchTargetKind(.edge)` の実行は InterfaceAdapters 側で `node/edge` 対象切替として扱う。
- 対象切替キーは `tab` を使用する。

補足:

- `cmd+k`（palette）、`cmd+f`（search）、`cmd+l`（connect）、undo/redo、zoom は `global` 管理であり primitive Intent 対象外。
- Add Node Mode Selection / Connect Node Selection / Command Palette 内キー操作は `modal` 管理であり primitive Intent 対象外。

#### 利用状況（どこから使われるか）

- 入力変換
  - `Sources/InterfaceAdapters/Input/Hotkey/CanvasHotkeyTranslator.swift`
    - `NSEvent` を `CanvasShortcutGesture` に正規化し、`resolveAction(for:)` で解決する。
    - `cmd+f` は現状 `CanvasShortcutCatalogService` ではなく専用判定で扱う（`global`）。
- UI 表示
  - `Sources/InterfaceAdapters/Output/SwiftUI/CanvasView.swift`
    - `commandPaletteDefinitions(context:)` の結果をコマンドパレット一覧表示に使用する。
    - `CanvasCommandPaletteContext.activeEditingMode` は以下の順で決定する。
      - フォーカスノードがある場合: フォーカスノード所属エリアの mode
      - フォーカスなしでエリア mode が一意の場合: その mode
      - 上記以外: `nil`（mode 依存項目は非表示）
    - mode が確定している場合、同一ショートカットでも文言を mode 別に上書きする（例: `copy/cut/paste`）。
- Debug API 出力
  - `Sources/InterfaceAdapters/Output/DebugState/CanvasDebugStateJSONMapper.swift`
    - `d5-shortcut-catalog` の状態ペイロード生成で `commandPaletteDefinitions()` / `commandPaletteDefinitions(context:)` を利用する。
- 主要テスト
  - `Tests/DomainTests/CanvasShortcutCatalogServiceTests.swift`
  - `Tests/InterfaceAdaptersTests/CanvasHotkeyTranslatorTests.swift`

#### 不変条件・エラー一覧

- 不変条件
  - 標準ショートカット定義は実装内の静的配列で管理し、入力解決とコマンドパレット表示で共有する。
  - `CanvasCommandPaletteVisibility` により、mode/フォーカス条件を満たさない項目は表示しない（無効表示は行わない）。
  - `CanvasCommandPaletteLabel` は `Noun: Verb` 形式でタイトルを生成し、コマンド名の表記ゆれを防ぐ。
  - `deleteSelectedOrFocusedNodes` の表示名は mode 共通で `Node: Delete Selected` とする。
  - edge ターゲット中の削除は `Edge: Delete Selected` を表示し、`deleteSelectedOrFocusedEdges` へ解決する。
  - `copySelectionOrFocusedSubtree` / `cutSelectionOrFocusedSubtree` / `pasteClipboardAtFocusedNode` は mode に応じて文言を切り替える（Tree は subtree を明示、Diagram は selected/paste を優先）。
  - `cmd+shift+arrow`（`nudgeNode`）は実行経路を維持しつつ、コマンドパレット表示は Diagram mode のみとする。
  - 状態依存の ON/OFF 操作は原則 `toggle` 動詞で表記し、`enable/disable/on/off` は検索トークンで吸収する。
  - `Shift + 矢印` は `.extendSelection` に解決し、`moveFocus` と競合しない。
  - `primitive` へ新規キーを追加する場合、Intent 層を経由しない実装を禁止する。
  - `global`/`modal` は Scope 判定で先に分離し、`primitive` Intent 解決経路へ混在させない。
  - Keymap 3 層解決順は `User Override -> Context/Mode Override -> Intent Base Map` を維持する。
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
  - `Sources/InterfaceAdapters/Output/DebugState/CanvasDebugStateJSONMapper.swift`
    - `d6-fold-visibility` の状態ペイロード生成で `hiddenNodeIDs(in:)` / `visibleNodeIDs(in:)` を利用する。
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
    - Diagram エリアでは `duplicateSelectionAsSibling` を不許可とする（`unsupportedCommandInMode`）。
    - Diagram エリアでは `connectNodes` を許可し、同一エリア内の既存ノード同士を `normal` エッジで接続する（自己接続・跨ぎ接続は no-op、同一ノード間の重複接続は許可）。接続成功時はフォーカスと選択を接続先ノードへ移す。
    - Tree エリアでは `moveNode` 実行時、フォーカスが選択集合に含まれ同一エリアで2件以上選択されている場合、選択ノード群をフォーカス移動先の親配下へ兄弟として再配置する。複数の親にまたがる選択でも移動後は同一親へ一本化し、選択内の親子関係はフラット化する。`up` / `down` は選択中の兄弟ノードを飛ばして非選択兄弟と入れ替え、複数選択を1ブロックとして並び替える。
    - Diagram エリアでは `moveNode` を8方向移動として扱う。接続アンカーがある場合はアンカー基準でステップ距離（`CanvasDefaultNodeDistance` 横 `220`・縦 `220`）を決定し、移動先がアンカーと同じ行/列でステップ距離未満になるときは移動方向の軸距離を最低1ステップに補正する。補正後も重なる場合のみ、同方向に追加ステップして重なりを回避する。接続アンカーがない場合でも、フォーカスノード自身の寸法を基準に同じグリッド間隔で移動できる。複数選択条件（フォーカスを含む同一エリア2件以上）を満たす場合は、フォーカスで解決した移動量を選択ノード群へ同一の平行移動として適用する。
    - Diagram エリアで `moveNode` を適用した後は、同一エリア内ノード衝突も即時解消するために area layout を実行する。
    - Diagram エリアでは `nudgeNode` も `moveNode` と同じ位置解決ロジック（アンカー距離補正と重なり回避を含む）を使い、ステップのみ `moveNode` の 1/4 倍（`cmd+矢印 : cmd+shift+矢印 = 4:1`）で移動する。複数選択条件を満たす場合は `moveNode` と同様に選択ノード群を一括平行移動する。
    - Diagram エリアでは `nudgeNode` 適用後も `moveNode` と同様に area layout を実行し、同一エリア内のノード重なりを即時解消する。
    - `scaleSelectedNodes` はフォーカスではなく `selectedNodeIDs` を対象に実行する。Tree では基準長（幅 `220` / 高さ `41`）に対する `10%` を1ステップとして加減算し、最小値を基準長の `50%` に制限する。Diagram では正方形を維持したまま辺長を `220 * 10%` ずつ加減算し、`110...330` の範囲へ正規化する。
    - `alignAllAreasVertically` は Tree/Diagram の両モードで実行可能とし、フォーカス有無で実行可否を判定しつつ、処理対象はキャンバス内の全エリアとする。各エリアの外接矩形を単位に、全エリアの最左 `x` へ揃え、`y` は上から順に重なりが解消される位置へ再配置する。ノード移動はエリア単位の一括平行移動で行い、各エリア内の相対配置は維持する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddNode.swift`
    - Diagram エリアでは `addNode` 実行時、フォーカスノードが存在する場合に `relationType = .normal` のエッジで新規ノードと接続する。
    - Diagram エリアで新規作成されるノードは、Tree ノード横幅（`220`）を一辺とする正方形で生成する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SetNodeText.swift`
    - Diagram エリアでは `setNodeText` 実行時に入力高さを採用せず、ノード寸法を正方形へ正規化する。辺長は `110...330` の範囲で現在辺長を維持する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+ScaleSelectedNodes.swift`
    - `scaleSelectedNodes` 実行時に、選択ノード群をモード別ルール（Tree: 幅/高さを比率ステップ、Diagram: 正方形辺長を比率ステップ）で一括更新する。
  - `Sources/Application/Coordinator/CanvasCommandPipelineCoordinator.swift`
    - グラフ変更後に Diagram エリア所属ノードの寸法を正方形へ正規化する。既存 Diagram ノードは `110...330` を維持し、`convertFocusedAreaMode` / `createArea` / `assignNodesToArea` で Diagram へ新規所属したノードは辺長 `220` へ初期化する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddChildNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddSiblingNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+ConnectNodes.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+DeleteFocusedNode.swift`
    - `deleteSelectedOrFocusedNodes` は複数選択時にフォーカス所属エリア内の選択ノードを削除対象へ昇格する。Tree では各選択ノードの subtree まで削除し、Diagram では選択ノード自体のみ削除する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+DeleteSelectedOrFocusedEdges.swift`
    - `deleteSelectedOrFocusedEdges` は focused edge を必ず削除対象に含める。選択集合に focused edge が含まれ、かつ2件以上選択されている場合は選択 edge を一括削除する。
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+CopyPasteSubtree.swift`
    - 追加/削除時の所属更新を行う。
    - `copySelectionOrFocusedSubtree` / `cutSelectionOrFocusedSubtree` は「同一フォーカスエリア内で複数選択が2件以上ある場合」に選択集合を対象として扱い、それ以外は従来どおりフォーカス部分木を対象とする。
    - `pasteClipboardAtFocusedNode` は Tree/Diagram の両モードで実行可能。Tree では貼り付けルート群をフォーカスノード配下に親子接続し、Diagram では内部エッジを保ったまま親子接続を追加せず同一エリアへ再構成する。貼り付け後の選択状態は、挿入された全ノード集合へ更新する。
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

## 6. ドメイン間の関係（依存・データ受け渡し）

1. `CanvasHotkeyTranslator` がキーイベントを `CanvasShortcutGesture` に正規化する。
2. `KeymapIntentResolver.resolveRoute(for:)` が `primitive/global` 経路を分類する（非対応は `nil`）。
3. `global` は専用経路（palette/search/history/zoom など）で処理する。
4. `primitive` は Intent を経由して ContextAction に解決し、最終的に `CanvasCommand` をディスパッチする。`modal` は Add Node Mode Selection / Connect Node Selection などの View 状態で処理する。
5. コマンド種別ごとに Domain サービスを利用する。
   - 編集: `CanvasGraphCRUDService`
   - フォーカス: `CanvasFocusNavigationService`
   - ツリー再レイアウト: `CanvasTreeLayoutService`
   - エリア衝突解消: `CanvasAreaLayoutService`
   - 折りたたみ可視性: `CanvasFoldedSubtreeVisibilityService`
   - エリア所属/モード解決: `CanvasAreaMembershipService`
6. 生成された `CanvasGraph` を `ApplyResult` 経由で ViewModel に返し、表示状態を更新する。

共通契約:

- `CanvasEdgeRelationType.parentChild` は、子孫探索・ツリー再配置・エリア分割/衝突解消で共有される。
- `CanvasGraph` は Application と InterfaceAdapters 間の共通スナップショットとして扱う。
- Domain サービスは `throw` せず、失敗はドメイン固有エラーの `Result` で返す。

## 7. 変更履歴

- 2026-02-15: 初版作成。
- 2026-02-15: `CanvasTreeLayoutService` を追加し、親子ツリー再配置の利用箇所と不変条件を追記。
- 2026-02-15: `CanvasCommand.moveNode` と `CanvasNodeMoveDirection` を追加し、`cmd+矢印キー` のネスト移動利用箇所を追記。
- 2026-02-15: `CanvasTreeLayoutService` の実装を `CanvasTreeLayoutService+Relayout.swift` と `CanvasTreeLayoutService+RelayoutInternals.swift` に分割（挙動変更なし）。
- 2026-02-15: `moveNode(.left)` の挙動を変更し、トップレベルノードの子からルート親方向への昇格を抑止するガードを追加。
- 2026-02-16: `CanvasShortcutCatalogService` とショートカット関連モデルを追加し、ホットキー解決とコマンドパレット一覧の情報源をドメインで統一。
- 2026-02-16: Domain サービスの失敗表現を `throw` から `Result<..., 各DomainError>` に統一し、Application 側は `.get()` で既存 `throws` 契約を維持。
- 2026-02-18: Viewport Intent の運用を更新し、フォーカス変化による自動 `.resetManualPanOffset` 生成を廃止（初期中央化/画面外補正は `CanvasView` の表示ルールで実施）。
- 2026-02-18: `ctrl+l` の `centerFocusedNode` コマンドを追加し、`apply` フローで `resetManualPanOffset` を返却することで、現在フォーカスノードを画面中央へ再配置する。
- 2026-02-18: 未使用だった Domain 公開 API（`CanvasGraphCRUDService.readNode/readEdge/updateEdge`、`CanvasShortcutCatalogService.defaultDefinitions/validate`、`CanvasShortcutCatalogError`）を削除。
- 2026-02-19: `toggleFoldFocusedSubtree` コマンドと `Option + .` ショートカットを追加し、`CanvasFoldedSubtreeVisibilityService` で折りたたみ可視性の計算を Domain に集約。
- 2026-02-21: Diagram mode Phase1 基盤として `CanvasArea*` モデル、`CanvasAreaMembershipService`、`CanvasAreaPolicyError`、モード別コマンドディスパッチ境界を追加。
- 2026-02-21: Diagram mode Phase2 として、`createArea` / `assignNodesToArea` の Diagram 実行許可、`addNode` の複数エリア曖昧解決エラー、跨ぎエッジ禁止（`crossAreaEdgeForbidden`）の強制を追加。
- 2026-02-21: Diagram mode Phase3 として `convertFocusedAreaMode(to:)` を追加し、フォーカス基準のモード変換（同一モード no-op）と `Shift + Enter` モード選択導線を実装。
- 2026-02-22: `CanvasNode.imagePath` と `CanvasCommand.setNodeImage` を追加し、ノード上部画像の挿入/置換をドメイン編集コマンドとして扱う仕様を追記。
- 2026-02-22: `CanvasNode` 初期化時の `imagePath` を必須化し、ノード再構築時に画像パスを明示伝播することで、画像データ欠落をコンパイル時に検出できるようにした。
- 2026-02-22: Tree PhaseA として `copySelectionOrFocusedSubtree` / `cutSelectionOrFocusedSubtree` / `pasteClipboardAtFocusedNode` と `Command + C/X/V` を追加し、アプリ内コピー&ペーストを導入。
- 2026-02-22: Diagram mode の編集導線を更新し、`addChildNode` を Diagram では `addNode` として解釈する仕様を追加。
- 2026-02-22: Diagram mode の `addNode` を更新し、フォーカスノードが存在する場合は新規ノードを `normal` エッジで接続する仕様を追加。
- 2026-02-22: Diagram mode のノード寸法ルールを更新し、Tree ノード横幅（`220`）を一辺とする正方形へ統一（`addNode` / `setNodeText` / エリアモード変換・再所属後の正規化を含む）。
- 2026-02-22: `CanvasNode.markdownStyleEnabled` と `toggleFocusedNodeMarkdownStyle` コマンドを追加し、コマンドパレットからフォーカスノード単位で Markdown スタイル適用を切り替え可能にした。
- 2026-02-22: `CanvasNodeMoveDirection` を8方向（斜め4方向を追加）へ拡張し、Diagram mode では `moveNode` を接続アンカー基準の8方向スロット移動に変更した。微調整移動は `nudgeNode`（`cmd+shift+矢印`）として分離した。
- 2026-02-23: Diagram mode の `moveNode` を更新し、アンカー周囲の固定8スロット再配置ではなく、現在位置を基準にした連続グリッド移動へ変更。候補位置がアンカー矩形と重なる場合は同方向へ飛び越える仕様を追加した。
- 2026-02-22: `alignAllAreasVertically` コマンドを追加し、Command Palette からフォーカスエリア内の親ノードを最左基準で縦一列に整列できるようにした（Tree/Diagram 両対応）。
- 2026-02-22: `CanvasDefaultNodeDistance` を更新し、Tree/Diagram の既定ノード間距離（Tree: 横 `32` / 縦 `24`、Diagram: 横 `220` / 縦 `220`）を Domain で一元管理する仕様へ更新。
- 2026-02-22: 新規ウィンドウ起動時の初期ノード自動生成を廃止し、ノード未存在時は `Shift + Enter` と同一の Tree/Diagram モード選択導線から最初のノードを追加する仕様へ更新。
- 2026-02-22: 全ノード削除後に複数空エリアが残る状態でも、`Shift + Enter` のモード選択追加が失敗しないように、ノード未存在時は選択モードに合うエリアを優先解決（なければ新規作成）する仕様へ更新。
- 2026-02-28: Keymap Primitive Phase 1/2 として `primitive/global/modal` 境界、primitive Intent 語彙、KeyTrigger 対応表、3層解決順をドメイン仕様へ追加し、`KeymapIntentResolver` を導入。
- 2026-02-28: edge 操作基盤として `CanvasFocusedElement` / `CanvasEdgeFocus` / `CanvasGraph.selectedEdgeIDs` を追加し、`CanvasFocusNavigationService.nextFocusedEdgeID` と `CanvasSelectionService` の edge 正規化を導入した。
- 2026-02-28: キーマップを更新し、`cmd+l` を Connect Node Selection（global）へ復帰、`tab` を `switchTargetKind(.edge)`（primitive）へ再割り当てした。
- 2026-02-28: `CanvasCommand.deleteSelectedOrFocusedEdges` を追加し、edge ターゲット中の delete/Command Palette から複数選択 edge の一括削除に対応した。
- 2026-02-23: `Shift + Enter` モード選択追加の empty graph 分岐を修正し、選択モードと不一致な `defaultTree` の誤優先を禁止。あわせて空グラフで area を事前作成した場合でも、履歴の `graphBeforeMutation` は必ず元グラフを保持して undo 整合性を維持するよう更新。
- 2026-02-23: `CanvasCommand.connectNodes` と `Command + L`（`beginConnectNodeSelection`）を追加し、Diagram エリアで既存ノード同士を接続できる操作導線を実装した。
- 2026-02-23: 画像専用の `CanvasNode.imagePath` と `CanvasCommand.setNodeImage` を廃止し、`CanvasAttachment` / `upsertNodeAttachment` に統合。ノード添付を将来拡張可能な複数要素として扱う仕様へ更新した。
- 2026-02-23: 複数選択の導入として `CanvasGraph.selectedNodeIDs`、`CanvasCommand.extendSelection`、`CanvasSelectionService` を追加。`Shift + 矢印` による選択拡張、パイプラインでの selection 正規化、表示側での複数選択ハイライト連携を追記した。
- 2026-02-23: `copySelectionOrFocusedSubtree` / `cutSelectionOrFocusedSubtree` / `pasteClipboardAtFocusedNode` を更新し、同一フォーカスエリア内の複数選択コピー&ペーストを Tree/Diagram の両モードで実行可能にした。Tree は貼り付け時に親子接続を追加し、Diagram は内部エッジのみを再構成する。
- 2026-02-23: Diagram mode の `moveNode` / `nudgeNode` の位置解決ロジックを共通化し、`nudgeNode` の移動量を `moveNode` の 1/4（4:1 比率）へ統一。`nudgeNode` でも area layout による重なり解消を適用する仕様へ更新。
- 2026-02-23: `deleteSelectedOrFocusedNodes` を拡張し、複数選択時はフォーカス所属エリア内の選択ノードを削除対象として扱う仕様を追加（Tree は subtree まで、Diagram は選択ノードのみ）。
- 2026-02-23: `moveNode` / `nudgeNode` を拡張し、フォーカスを含む同一エリア複数選択時は一括移動に対応。Tree では移動後に選択ノードを同一親配下の兄弟へ一本化し、Diagram ではフォーカス基準の移動量を選択ノード群へ同一平行移動として適用する仕様を追加。
- 2026-02-23: `CanvasCommand.duplicateSelectionAsSibling` と `Command + D` を追加し、Tree エリアで「選択優先・未選択時はフォーカス」のサブツリー複製を sibling 追加として実行する仕様を導入した。Diagram エリアでは不許可とした。
- 2026-02-26: `CanvasCommandPaletteLabel` を追加し、コマンドパレット表示名を `Noun: Verb` へ統一。状態依存操作は `toggle` 表記を標準とし、`enable/disable/on/off` は検索トークンで補完する仕様へ更新。
- 2026-02-26: 画像添付時の Diagram ノード寸法ルールを更新し、`upsertNodeAttachment` で `nodeWidth` を受け取って `220...330` の正方形を許可。画像なしは従来どおり `220` 正方形を維持し、`setNodeText` とパイプライン正規化でも同ルールを適用する仕様へ更新。
- 2026-02-26: Diagram mode の `moveNode` / `nudgeNode` を更新し、アンカーと同じ行/列で移動先が近すぎる場合は移動方向の軸距離を最低1ステップへ補正して、左右/上下で見かけの間隔が偏らないようにした。補正後に重なる場合のみ追加ステップで回避する。
- 2026-02-26: `alignAllAreasVertically` を更新し、フォーカス中エリア内の親サブツリー整列から、キャンバス内の全エリアを左詰め縦整列する挙動へ変更。整列時はエリア内ノードの相対配置を保持したまま、エリア単位で平行移動する仕様へ更新した。
- 2026-02-28: `pasteClipboardAtFocusedNode` を更新し、複数ノード貼り付け後の `selectedNodeIDs` を先頭ルート1件ではなく、挿入された全ノード集合へ更新する仕様に変更。
- 2026-02-28: `CanvasCommand.scaleSelectedNodes` と `CanvasNodeScaleDirection` を追加し、`⌘⌥+` / `⌘⌥-`（互換キーコードを含む）で選択ノードの拡大縮小を実行可能にした。拡縮量は基準長に対する比率（`nodeScaleStepRatio = 0.1`）で一元管理し、Diagram ノードは `110...330` の正方形へ正規化する仕様へ更新した。
- 2026-03-01: Diagram エリアの `connectNodes` を更新し、同一ノード間の `normal` エッジ重複接続を許可した。重複エッジは表示時にレーン分離で描画し、edge フォーカス移動では同一点エッジ群を方向キーで巡回できる仕様へ更新した。
- 2026-03-01: `CanvasFocusNavigationService.nextFocusedEdgeID` を更新し、重複 edge の巡回を方向候補探索より優先するよう変更。巡回対象は「同一 endpoint ペア（無向・relationType 一致）」に限定し、中心座標一致のみの無関係 edge への遷移を禁止した。
