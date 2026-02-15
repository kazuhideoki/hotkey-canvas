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
- エラー
  - `CanvasGraphError`
- サービス
  - `CanvasGraphCRUDService`

#### サービス詳細

`CanvasGraphCRUDService` はグラフ編集の純粋 CRUD を提供する。

| メソッド | 責務 |
| --- | --- |
| `createNode(_:in:)` | ノードを追加し、新しい `CanvasGraph` を返す。 |
| `readNode(id:in:)` | ノードを参照する。 |
| `updateNode(_:in:)` | 既存ノードを置換する。 |
| `deleteNode(id:in:)` | ノードを削除し、接続エッジも同時に除去する。削除対象がフォーカス中なら `focusedNodeID` を `nil` にする。 |
| `createEdge(_:in:)` | エッジを追加し、新しい `CanvasGraph` を返す。 |
| `readEdge(id:in:)` | エッジを参照する。 |
| `updateEdge(_:in:)` | 既存エッジを置換する。 |
| `deleteEdge(id:in:)` | エッジを削除する。 |

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
| `makeParentChildAreas(in:)` | `parentChild` エッジを無向辺として連結成分を作り、各成分の外接矩形を計算して返す。 |
| `resolveOverlaps(areas:seedAreaID:minimumSpacing:maxIterations:)` | seed 領域を起点に衝突を伝播解消し、領域ごとの移動量を返す。 |

アルゴリズム要点:

- `makeParentChildAreas(in:)`
  - ノード ID 昇順で探索し、BFS で連結成分を抽出。
  - ノードが存在しないエッジ終端は無視。
  - 領域 ID は成分内の最小ノード ID を代表値として使う。
- `resolveOverlaps(...)`
  - 初期衝突では seed 領域と最初の衝突領域を半分ずつ移動。
  - その後はキュー駆動で衝突先を順次押し出す。
  - 同一中心時は ID 順に tie-break し、決定性を維持。
  - `numericEpsilon` 未満の移動は無効として切り捨てる。

#### 利用状況（どこから使われるか）

- Application 共有ヘルパー
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SharedHelpers.swift`
    - `parentChildArea(...)`
    - `resolveAreaOverlaps(...)`
- 間接利用（ノード追加系）
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddChildNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddSiblingNode.swift`
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

- Application 共有ヘルパー
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SharedHelpers.swift`
    - `relayoutParentChildTrees(in:)`
- 間接利用（構造変更・サイズ変更系）
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddChildNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+AddSiblingNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+DeleteFocusedNode.swift`
  - `Sources/Application/UseCase/ApplyCanvasCommands/ApplyCanvasCommandsUseCase+SetNodeText.swift`
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

## 5. ドメイン間の関係（依存・データ受け渡し）

1. `CanvasHotkeyTranslator` がキーイベントを `CanvasCommand` に変換する。
2. `ApplyCanvasCommandsUseCase` がコマンドをディスパッチする。
3. コマンド種別ごとに Domain サービスを利用する。
   - 編集: `CanvasGraphCRUDService`
   - フォーカス: `CanvasFocusNavigationService`
   - ツリー再レイアウト: `CanvasTreeLayoutService`
   - エリア衝突解消: `CanvasAreaLayoutService`
4. 生成された `CanvasGraph` を `ApplyResult` 経由で ViewModel に返し、表示状態を更新する。

共通契約:

- `CanvasEdgeRelationType.parentChild` は、子孫探索・ツリー再配置・エリア分割/衝突解消で共有される。
- `CanvasGraph` は Application と InterfaceAdapters 間の共通スナップショットとして扱う。

## 6. 変更履歴

- 2026-02-15: 初版作成。
- 2026-02-15: `CanvasTreeLayoutService` を追加し、親子ツリー再配置の利用箇所と不変条件を追記。
- 2026-02-15: `CanvasCommand.moveNode` と `CanvasNodeMoveDirection` を追加し、`cmd+矢印キー` のネスト移動利用箇所を追記。
