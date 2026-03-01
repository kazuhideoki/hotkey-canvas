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
| `moveNode` | `cmd+arrow` | 構造移動（並び替え/indent/outdent） | 位置移動（diagram grid） | |
| `nudgeNode` | `cmd+shift+arrow` | 実行経路はあるが no-op | 微小移動 | |
| `toggleVisibility` | `opt+.` | subtree の fold/unfold 切替 | 非対応 | |
| `switchTargetKind(.edge)` | `tab` | node/edge 対象を切替 | node/edge 対象を切替 | edge 対象中の `tab` は node へ戻す |

## 補足

- `modal`（Command Palette / Add Node Mode Selection / Connect Mode 内操作）は本表の対象外です。
- Command Palette では edge 対象時に `Edge: Delete Selected` が表示され、`delete` と同じ削除規則（focused edge を含む複数選択は一括削除）が適用されます。
- Add Node Mode Selection では `t` / `d` / `enter` に加えて、`↑` / `↓` で選択移動、`esc` でキャンセルが可能です。
- Connect Mode では `↑` / `↓` / `←` / `→` で候補移動、`enter` で確定、`esc` でキャンセルが可能です。
- 入力正規化として、`fn+arrow` と `fn+delete` は `fn` を無視して通常ショートカットとして解決されます。
- `attach` / `transform` / `output` / `export` / `import` は現状ショートカット未割当です。
