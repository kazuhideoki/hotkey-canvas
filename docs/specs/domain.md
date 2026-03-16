# HotkeyCanvas ドメインドキュメント

## 1. ドキュメントの目的

- `Sources/Domain/` の現在の仕様をドメイン単位で整理し、実装時の判断基準を明確にする。
- Domain の構造、公開契約、不変条件、主要な利用境界をまとめ、仕様と実装のずれを防ぐ。
- ドメイン変更時に、どの型・サービス・不変条件を更新すべきかを追跡しやすくする。

## 2. スコープ

- 本書は `Sources/Domain/` の型・サービスを主対象とする。
- `Sources/Application/` と `Sources/InterfaceAdapters/` からの主要な利用境界までは扱うが、実行順序や UI 表示制御そのものは主対象にしない。
- 具体的なキートリガー割り当ては `docs/specs/keymap.md` を正本とし、本書では解決契約と不変条件に絞って扱う。
- 更新ルールは `AGENTS.md` に従う。

## 3. 関連ドキュメント

- ドメイン構造の関係図: `docs/specs/domain-er.md`
- キーマップの具体的な割り当て: `docs/specs/keymap.md`
- レイヤー責務と Application 側の編集パイプライン: `docs/specs/architecture.md`

## 4. ドメイン一覧（索引）

| ID | ドメイン名 | 主な型/サービス |
| --- | --- | --- |
| D1 | キャンバスグラフ編集 | `CanvasGraph`, `CanvasFocusedElement`, `CanvasEdgeFocus`, `CanvasNode`, `CanvasEdge`, `CanvasCommand`, `CanvasDefaultNodeDistance`, `CanvasGraphCRUDService`, `CanvasGraphError` |
| D2 | フォーカス移動と複数選択 | `CanvasFocusDirection`, `CanvasFocusNavigationService`, `CanvasSelectionService` |
| D3 | エリアレイアウトと衝突解消 | `CanvasNodeArea`, `CanvasCollisionBodyID`, `CanvasCollisionBody`, `CanvasCollisionShape`, `CanvasRect`, `CanvasTranslation`, `CanvasAreaLayoutService`, `CanvasCollisionResolutionService` |
| D4 | ツリーレイアウト | `CanvasTreeLayoutService` |
| D5 | ショートカットカタログ | `CanvasCommandPaletteLabel`, `CanvasShortcutDefinition`, `CanvasShortcutGesture`, `CanvasShortcutAction`, `CanvasShortcutCatalogService`, `KeymapPrimitiveIntent`, `KeymapGlobalAction`, `KeymapResolvedRoute`, `KeymapIntentResolver` |
| D6 | 折りたたみ可視性 | `CanvasFoldedSubtreeVisibilityService` |
| D7 | エリアモード所属管理 | `CanvasAreaID`, `CanvasEditingMode`, `CanvasArea`, `CanvasAreaEdgeShapeStyle`, `CanvasAreaMembershipService`, `CanvasAreaPolicyError` |

## 5. ドメイン横断契約

- `CanvasGraph` は D1-D7 が共有するキャンバス全体の不変スナップショットであり、Application / InterfaceAdapters との受け渡し単位でもある。
- `CanvasEdgeRelationType.parentChild` は、親子構造を表すドメイン共通の関係種別として扱う。
- Domain サービスは純粋計算または純粋状態変換に限定し、失敗は `throw` ではなくドメイン固有エラーの `Result` で返す。
- 具体的な編集パイプライン順序、`CanvasViewportIntent` 生成、UI 表示ルールは Domain ではなく Application / InterfaceAdapters の責務とする。
- 具体的なキートリガー割り当ては `docs/specs/keymap.md` を正本とし、Domain では Scope・Intent・解決順といった抽象契約を扱う。

## 6. 各ドメイン詳細

### D1. キャンバスグラフ編集ドメイン

#### 構造

- 集約
- `CanvasGraph`: ノード/エッジ/フォーカス/選択集合/折りたたみルートを保持する不変スナップショット。
- エンティティ/値オブジェクト
  - `CanvasNode`, `CanvasNodeID`, `CanvasNodeKind`, `CanvasBounds`（`CanvasNode.attachments` はノード内添付、`CanvasNode.markdownStyleEnabled` は確定描画時 Markdown スタイル適用可否、`CanvasNode.metadata["createdOrder"]` は作成順メタデータ）
  - `CanvasAttachment`, `CanvasAttachmentID`, `CanvasAttachmentKind`, `CanvasAttachmentPlacement`
  - `CanvasEdge`, `CanvasEdgeID`, `CanvasEdgeRelationType`, `CanvasEdgeDirectionality`（`parentChild` エッジは `parentChildOrder` で兄弟順序を保持、`directionality` は `none/fromTo/toFrom` で矢印表示方向を保持）
  - `CanvasFocusedElement`（`.node` / `.edge` / `.area` の操作対象）
  - `CanvasEdgeFocus`（`edgeID` と `originNodeID` を保持する edge フォーカス情報）
  - `CanvasDefaultNodeDistance`（既定ノード間距離。`treeHorizontal = 32`、`treeVertical = 24`、`diagramHorizontal = 220`、`diagramVertical = 220`、画像添付時の Diagram ノード上限 `diagramImageMaxSide = 330`、Diagram ノード最小辺長 `diagramMinNodeSide = 110`、選択ノード拡縮ステップ `nodeScaleStepRatio = 0.1`）
- コマンド
  - `CanvasCommand`
  - `CanvasNodeMoveDirection`
  - `CanvasNodeAlignmentAxis`
  - `CanvasNodeScaleDirection`
  - `CanvasCommand.nudgeNode`
  - `CanvasCommand.alignSelectedNodes`
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
  - `CanvasCommand.cycleFocusedEdgeDirectionality(focusedEdge:selectedEdgeIDs:)`
  - `CanvasCommand.setEdgeLabel(edgeID:label:)`
  - `CanvasCommand.duplicateSelectionAsSibling`
  - `CanvasCommand.toggleFocusedNodeMarkdownStyle`
  - `CanvasCommand.toggleFocusedAreaEdgeShapeStyle`
  - `CanvasCommand.alignAllAreasVertically`
  - `CanvasCommand.extendSelection`
  - `CanvasCommand.focusNode(CanvasNodeID)`
  - `CanvasCommand.focusArea(CanvasAreaID)`
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

#### 主要な利用境界

- Application の編集系ユースケースが、ノード・エッジ・添付・フォーカス対象の更新に利用する。
- Input Port / Hotkey / Command Palette / ViewModel から流入する編集コマンドの中心的な操作対象となる。

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
  - `CanvasGraph.focusedElement == .area(areaID)` のとき、`areaID` は必ず `areasByID` に存在し、`focusedNodeID` は既存コマンド互換のアンカーノードとして保持する。
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

仕様上の要点:

- 候補ノードは移動方向の前方から選び、決定結果は同一入力に対して決定的になるようにする。
- edge フォーカスでは、同一 endpoint ペア（無向・relationType 一致）の重複 edge がある場合、方向候補探索より先に重複束内を巡回する。
- 空グラフでは `nil` を返し、候補なしでは現在フォーカスを維持する。

`CanvasSelectionService` は複数選択状態の正規化を担当する。

| メソッド | 責務 |
| --- | --- |
| `normalizedSelectedNodeIDs(from:in:focusedNodeID:)` | 可視ノード以外を除外し、フォーカスノードを必ず選択集合へ含める。 |
| `normalizedSelectedNodeIDs(in:)` | `CanvasGraph` 内の `selectedNodeIDs` を正規化する。 |
| `normalizedSelectedEdgeIDs(from:in:focusedEdgeID:)` | 既存 edge 以外を除外し、フォーカス edge を必ず選択集合へ含める。 |
| `normalizedSelectedEdgeIDs(in:)` | `CanvasGraph` 内の `selectedEdgeIDs` を正規化する。 |

#### 主要な利用境界

- Application のフォーカス移動・選択拡張・フォーカス正規化で利用する。
- Input / View 側では、方向キー操作、検索解除時のフォーカス復元、複数選択同期の基準として利用する。

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

### D3. エリアレイアウトと衝突解消ドメイン

#### 構造

- モデル
  - `CanvasNodeArea`: 親子接続成分をひとまとまりの領域として表現する。
  - `CanvasCollisionBodyID`: collision body 専用の識別子。単一 node body と cluster body を別 namespace で表現する。
  - `CanvasCollisionBody`: 1 ノードまたは複数選択ノード群を、同一移動量で動く衝突単位として表現する。
  - `CanvasCollisionShape`: 1 つ以上の矩形の union として衝突形状を表現する。
  - `CanvasAreaShapeKind`: 領域形状の生成戦略（矩形/凸包）を表現する。
  - `CanvasAreaShape`: 領域の外周形状（矩形/凸包頂点列）を表現する。
  - `CanvasPoint`: 凸包頂点や投影計算に使う 2D 座標値オブジェクト。
  - `CanvasRect`: 軸平行矩形の幾何計算を担う。
  - `CanvasTranslation`: 2D 平行移動量。
- 参照契約
  - `CanvasEdgeRelationType.parentChild` を接続判定に使用する。
- サービス
  - `CanvasAreaLayoutService`
  - `CanvasCollisionResolutionService`

#### サービス詳細

`CanvasAreaLayoutService` は親子構造を保ったレイアウト領域抽出と衝突解消を担当する。

| メソッド | 責務 |
| --- | --- |
| `makeParentChildAreas(in:shapeKind:)` | `parentChild` エッジを無向辺として連結成分を作り、指定戦略で領域形状（矩形/凸包）を構築して返す。 |
| `resolveOverlaps(areas:seedAreaID:minimumSpacing:maxIterations:)` | seed 領域を起点に衝突を伝播解消し、領域ごとの移動量を返す。 |

仕様上の要点:

- `makeParentChildAreas(in:)` は `parentChild` 接続成分ごとに領域を構成し、指定戦略に応じて矩形または凸包の形状を返す。
- `resolveOverlaps(...)` は seed 領域を起点に衝突解消を伝播させ、決定的な移動量を返す。

`CanvasCollisionResolutionService` は Diagram 文脈の node / node-cluster 衝突解消を担当する。

| メソッド | 責務 |
| --- | --- |
| `resolveOverlaps(bodies:seedBodyID:minimumSpacing:seedPreferredMoveDirection:maxIterations:)` | seed body を起点に衝突解消を伝播し、body ごとの移動量を返す。 |

仕様上の要点:

- `CanvasCollisionShape` は矩形集合の union を表現し、凸包ではなく実際の矩形配置に基づいて衝突判定する。
- `resolveOverlaps(...)` は body を cardinal direction のみで押し出し、concave な gap に存在する別 body を不要に押し出さない。
- `seedPreferredMoveDirection` を与えた場合、seed body 自体の slot を保ちつつ、その移動方向を優先して衝突相手を押し出す。

#### 主要な利用境界

- Application の area layout 段、Diagram の複数選択 node move 後の衝突解消、ノード追加時の配置候補計算で利用する。
- `CanvasRect` などの幾何モデルは、描画範囲や当たり判定に関わる出力計算でも利用する。

#### 不変条件・エラー一覧

- 不変条件
  - `minimumSpacing` は 0 未満を許容せず 0 に丸める。
  - `maxIterations <= 0` または領域数 1 以下の場合は移動なし。
  - `seedAreaID` が領域に存在しない場合は移動なし。
  - 返却値には非ゼロ移動のみ含める。
  - `CanvasCollisionShape` の矩形集合は空を許容しない。
  - `CanvasCollisionResolutionService.resolveOverlaps(...)` は seed body が存在しない場合、または初回衝突がない場合は移動なし。
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

仕様上の要点:

- `parentChild` エッジのみを対象に再配置する。
- 子ノード順は `parentChildOrder` を優先し、未設定時のみ決定的な座標順へフォールバックする。
- ルート位置を基準に、親子構造を保ったまま決定的に再配置する。

#### 主要な利用境界

- Application の tree layout 段で利用する。

#### 不変条件・エラー一覧

- 不変条件
  - `verticalSpacing` / `horizontalSpacing` / `rootSpacing` は 0 未満を許容せず 0 に丸める。
  - `parentChild` エッジが存在しない場合は空の更新結果を返す。
  - 返却値は親子接続成分に含まれるノードのみを対象とする。
  - 同一入力に対して決定的な結果を返す（順序 tie-break を含む）。
- エラー
  - ドメインエラー型は持たず、`throws` しない。

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
  - `KeymapExecutionRoute`
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
| `definition(for:)` | `CanvasCommand` から定義を逆引きし、実行/表示/ルート判定に再利用する。 |
| `KeymapIntentResolver.resolveRoute(for:)` | `CanvasShortcutGesture` を `primitive/global` の経路へ分類し、`primitive` のみ Intent を返す（非対応は `nil`）。`modal` は View の状態管理で扱う。 |

#### 解決契約

- Scope は `primitive` / `global` / `modal` の 3 種で固定する。
- `KeyTrigger -> Intent -> ContextAction` は `primitive` スコープでのみ適用する。
- `global` と `modal` は Intent 解決経路に混在させず、専用ルートで扱う。
- Input Adapter の公開経路は `CanvasHotkeyTranslator.resolve(_:) -> KeymapResolvedRoute?` に一本化する。
- Intent 解決順は `User Override -> Context/Mode Override -> Intent Base Map` を固定順とする。
- 実際のキートリガー対応表は `docs/specs/keymap.md` を正本とする。

#### Primitive Intent 語彙

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

Intent 補足:

- Intent は修飾キーを保持しない。
- 同一プリミティブ内の意味差分は Intent variant で扱う（例: `add` の追加位置差分）。
- `area target` では `moveNode` Intent を `CanvasCommand.moveArea` へ再解釈して実行する。
- `area target` では `add(.modeSelect)` を許可し、確定時は新規 area 作成後に追加 node へフォーカスして node target へ遷移する。キャンセル時は area target を維持する。

Scope 補足:

- palette / search / connect / undo / redo / zoom / center focused node は `global` 管理であり primitive Intent 対象外。
- Add Node Mode Selection / Connect Node Selection / Command Palette 内キー操作は `modal` 管理であり primitive Intent 対象外。
- `switchTargetKind(.cycle)` は InterfaceAdapters 側で `node -> edge -> area -> node` の対象切替として扱う（利用不可対象はスキップ）。
- `cycleFocusedEdgeDirectionality` は edge ターゲット中のみ有効で、対象 edge の矢印状態を `none -> fromTo -> toFrom -> none` で巡回する。

#### 主要な利用境界

- Input Adapter でショートカット入力を解決する際の単一情報源として利用する。
- Command Palette と Debug 出力で、表示可能なコマンド定義を共有する。

#### 不変条件・エラー一覧

- 不変条件
  - 標準ショートカット定義は実装内の静的配列で管理し、入力解決とコマンドパレット表示で共有する。
  - `CanvasCommandPaletteVisibility` により、mode/フォーカス条件を満たさない項目は表示しない（無効表示は行わない）。
- `CanvasCommandPaletteLabel` はコマンド名の表記ゆれを避けるための標準表現を提供する。
- `moveFocus` / `extendSelection` / `deleteSelectedOrFocusedNodes` は edge 対象時だけ edge ルートへ振り分け、node ルートと分離して扱う。
- `copySelectionOrFocusedSubtree` / `cutSelectionOrFocusedSubtree` / `pasteClipboardAtFocusedNode` などの表示名は mode に応じて切り替え可能とする。
- 微小移動コマンドは実行経路を維持しつつ、コマンドパレット表示は Diagram mode のみとする。
- 状態依存の ON/OFF 操作は原則 `toggle` 動詞で表記し、`enable/disable/on/off` は検索トークンで吸収する。
- 選択拡張は `moveFocus` と競合しない独立経路として扱う。
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

#### 主要な利用境界

- Application の fold/unfold 操作と可視グラフ基準のフォーカス正規化で利用する。
- ViewModel / Debug 出力では、描画対象となる可視グラフの導出に利用する。

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
  - `CanvasArea`（`id`, `nodeIDs`, `editingMode`, `edgeShapeStyle`）
  - `CanvasAreaEdgeShapeStyle`（`legacy` / `curved` / `straight`）
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
| `focusedAreaID(in:)` | フォーカス対象からエリアIDを解決する（`focusedElement == .area` を優先し、未指定時はフォーカスノード所属を解決）。 |
| `area(withID:in:)` | エリアIDからエリア情報を取得する。 |
| `convertFocusedAreaMode(to:in:)` | フォーカスノード所属エリアの編集モードを変換する（同一モード指定は no-op 成功）。 |
| `toggleFocusedAreaEdgeShapeStyle(in:)` | フォーカスエリアの edge 描画スタイル（`legacy` → `curved` → `straight` → `legacy`）を循環切替する。 |
| `createArea(id:mode:nodeIDs:in:)` | 新規エリアを作成する。 |
| `assign(nodeIDs:to:in:)` | ノード集合を指定エリアへ再所属させる。 |
| `remove(nodeIDs:in:)` | ノード集合を全エリア所属から除外する。 |

#### モード別ポリシー

- Tree は親子構造の編集を主とし、`moveNode` は構造移動として扱う。top-level root に対する `moveNode` は no-op とする。
- Diagram は配置編集を主とし、`addChildNode` は `addNode` へ正規化し、ノード寸法は正方形として扱う。
- Diagram では `duplicateSelectionAsSibling` を不許可とし、同一エリア内での `connectNodes` を許可する。
- `moveArea` は area target に対するエリア単位移動として扱う。
- `scaleSelectedNodes` は `selectedNodeIDs` を対象に実行し、寸法ルールは mode ごとに異なる。
- `alignAllAreasVertically` は Tree / Diagram の両モードで実行可能とし、`alignSelectedNodes` は Diagram 専用とする。
- `copySelectionOrFocusedSubtree` / `cutSelectionOrFocusedSubtree` / `pasteClipboardAtFocusedNode` / `deleteSelectedOrFocusedNodes` は、同一フォーカスエリア内の選択集合を優先しつつ、結果の解釈は mode ごとに異なる。

#### 主要な利用境界

- Application のコマンドディスパッチで、所属整合性検証と対象エリア解決に利用する。
- エリア管理コマンド、mode 別コマンド正規化、Diagram ノード正規化の基準として利用する。

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
