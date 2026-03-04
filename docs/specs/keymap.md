# キーマップ一覧

本ドキュメントは、現行実装のキーマップを `Global` と `Primitive` に分けて整理した一覧です。  
`Primitive` は `EditMode`（`tree` / `diagram`）ごとの差分が分かる形式で記載します。

## Global

| KeyTrigger | Route | 動作 | EditMode差分 |
| --- | --- | --- | --- |
| `cmd+k` / `cmd+shift+p` | `global.openCommandPalette` | Command Palette を開く | なし |
| `cmd+f` | `global.openSearch` | Search UI を開く | なし |
| `cmd+z` | `global.undo` | Undo | なし |
| `cmd+shift+z` / `cmd+y` | `global.redo` | Redo | なし |
| `cmd+=` / `cmd+shift+=` / `cmd+shift+;` / `cmd+テンキー+` | `global.zoomIn` | Zoom In | なし |
| `cmd+-` | `global.zoomOut` | Zoom Out | なし |
| `cmd+l` | `global.beginConnectNodeSelection` | Connect Mode を開始 | Tree は実質 no-op / Diagram で有効 |
| `ctrl+l` | `global.centerFocusedNode` | Focused Node を中央へ移動 | なし（フォーカス必須） |

## Primitive（EditMode差分）

| Primitive | KeyTrigger | Tree (`.tree`) | Diagram (`.diagram`) | 備考 |
| --- | --- | --- | --- | --- |
| `add(.primary)` | `enter` | 兄弟ノードを下に追加 | 非対応 | |
| `add(.alternate)` | `opt+enter` | 兄弟ノードを上に追加 | 非対応 | |
| `add(.hierarchical)` | `cmd+enter` | 子ノード追加 | `addNode` に正規化して追加 | |
| `add(.modeSelect)` | `shift+enter` | Add Node Mode 選択ポップアップを開く | Add Node Mode 選択ポップアップを開く | `t` / `d` / `enter` で確定 |
| `delete` | `delete` | 選択/フォーカスノードを削除 | node対象: 選択/フォーカスノードを削除 / edge対象: 選択/フォーカスedgeを削除 | edge対象で focused edge を含む複数選択時は一括削除 |
| `duplicate` | `cmd+d` | 兄弟として複製 | 非対応 | |
| `edit.copySelectionOrFocusedSubtree` | `cmd+c` | 複数選択時は選択集合、単一/未選択時は focused subtree をコピー | 複数選択時は選択集合、単一/未選択時は focused subtree をコピー | |
| `edit.cutSelectionOrFocusedSubtree` | `cmd+x` | 複数選択時は選択集合、単一/未選択時は focused subtree をカット | 複数選択時は選択集合、単一/未選択時は focused subtree をカット | |
| `edit.pasteClipboardAtFocusedNode` | `cmd+v` | 子として貼り付け | 貼り付け | |
| `moveFocus(.single)` | `arrow` | フォーカス移動 | フォーカス移動 | |
| `moveFocus(.extendSelection)` | `shift+arrow` | 選択拡張 | 選択拡張 | |
| `moveFocus(.acrossAreasToRoot)` | `cmd+opt+←/→` | 隣接エリアへ移動し、遷移先エリアのルート node へフォーカス | 隣接エリアへ移動し、遷移先エリアの最初に作成された node へフォーカス | node/area target の両方で有効。端では反対端へループ |
| `moveNode` | `cmd+arrow` | 構造移動（並び替え/indent/outdent） | 位置移動（diagram grid） | area target 時は `moveArea`（エリア単位平行移動 + エリア衝突解消）として実行 |
| `nudgeNode` | `cmd+shift+arrow` | 実行経路はあるが no-op | 微小移動 | |
| `toggleVisibility` | `opt+.` | subtree の fold/unfold 切替 | 非対応 | |
| `switchTargetKind(.cycle)` | `tab` | node/edge/area 対象を巡回 | node/edge/area 対象を巡回 | `node -> edge -> area -> node`（利用不可対象はスキップ） |

## 補足

- `modal`（Command Palette / Add Node Mode Selection / Connect Mode 内操作）は本表の対象外です。
- `operation target = area` のときは、area 操作と直接関係しない node/edge 対象ショートカットを無効化する。  
  例: `enter` / `opt+enter` / `cmd+enter` / `shift+enter` / `delete` / `cmd+d` / `cmd+c` / `cmd+x` / `cmd+v` / `shift+arrow` / `cmd+shift+arrow` / `cmd+opt++` / `cmd+opt+=` / `cmd+opt+shift+=` / `cmd+opt+shift+;` / `cmd+opt+-` / `opt+.` / `cmd+l` / `cmd+;` / `ctrl+l`
- `operation target = area` での `cmd+arrow` は `moveArea` として扱い、フォーカス中エリアを上下左右へ移動する。移動後にエリア衝突があれば area layout で解消する。
- Command Palette のカタログ項目は、`openCommandPalette` トリガーを除き「ショートカット定義がある項目」を表示対象にする。表示可否は直接ショートカットと同じ `executionCondition` で判定する。
- edge 対象で `moveFocus` / `extendSelection` / `deleteSelectedOrFocusedNodes` を使う場合は、`KeymapExecutionRoute: .edgeAware` として同一入力を edge ハンドリングへ委譲する。
- edge 対象では `ctrl+a` / `ctrl+e` / 直接文字入力で edge ラベルのインライン編集を開始できる。`ctrl+a` はカーソル先頭、`ctrl+e` はカーソル末尾で開始する。
- edge にラベル文字列がある場合は、edge ルート中央に最小限のラベル枠を表示する。
- モード差分や正規化ルールは上記 `Primitive（EditMode差分）` の各行を正本とし、Command Palette も同じ条件系に従う。
- Command Palette では edge 対象時に `Edge: Delete Selected` が表示され、`delete` と同じ削除規則（focused edge を含む複数選択は一括削除）が適用されます。
- Command Palette では起動直後（検索語句が空）に `↑` で検索語句履歴を過去方向へ 1 件ずつ呼び出し、`↓` で新しい方向へ戻せる。最新入力まで戻りきった後の `↓` は従来どおり候補リストのスクロールに使える。
- Add Node Mode Selection では `t` / `d` / `enter` に加えて、`↑` / `↓` で選択移動、`esc` でキャンセルが可能です。
- Connect Mode では `↑` / `↓` / `←` / `→` で候補移動、`enter` で確定、`esc` でキャンセルが可能です。
- 入力正規化として、`fn+arrow` と `fn+delete` は `fn` を無視して通常ショートカットとして解決されます。
- `attach` / `transform` / `output` / `export` / `import` は現状ショートカット未割当です。
