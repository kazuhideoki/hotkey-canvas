# Keymap Primitive 再設計計画

## 1. 目的

- Tree/Diagram で具体操作が異なっても、ユーザーのメンタルモデルを維持できるショートカット体系へ整理する。
- キー割り当てそのものではなく、操作意図を中心に設計し、Context ごとの差分を分離する。
- 本計画では既存実装の挙動を踏襲し、未実装領域は「導線準備」までを対象にする。

## 2. 固定方針

### 2.1 3層モデル

- `KeyTrigger`: 物理キー入力と修飾キーの組み合わせ。
- `ShortcutScope`: `primitive`（Tree/Diagram 操作プリミティブ）、`global`（cmd+k/cmd+z/cmd+= など）、`modal`（モーダル内操作）を先に判定する。
- `Intent`: KeyTrigger が表す抽象意図。
- `ContextAction`: Context（Tree/Diagram）に依存する具体アクション。

設計ルール:

- 重要: `global` と `modal` を Scope 判定で分離しないと、実装時に `cmd+k`/`cmd+z`/`cmd+=` 系が `Intent` 経路に混線し、ルール整合が崩れる。
- `KeyTrigger -> Intent -> ContextAction` は `primitive` スコープのみに適用する。
- 同一 Intent は Context に応じて ContextAction を切り替える。
- キー変更議論と機能意味議論を分離するため、Intent を先に固定する。
- 修飾キー（`cmd/ctrl/opt/shift`）は `KeyTrigger -> Intent` 変換時のみ利用し、Intent 値には保持しない。
- 同一プリミティブ内の意味差分は、修飾キーではなく Intent の variant で表現する。
  - 例: `add` は `add(variant: .primary/.alternate/.hierarchical/.modeSelect)` のように扱う。

### 2.2 メタキー意味の固定

- `cmd`: 実行系（編集・変形・履歴など）
- `ctrl`: 表示系（表示位置・表示モード・編集カーソル制御）
- `opt`: 副操作（バリエーション・補助挙動）
- `shift`: 反転/拡張（逆方向・範囲拡張・微調整）

注記:

- 現状実装は完全準拠ではないが、今後の追加はこの意味に収束させる。
- 既存ショートカットは互換性維持のため当面維持する。

### 2.3 レイヤー責務の固定

- Domain:
  - `Intent` の語彙と意味定義を保持する。
  - ContextAction の状態を持たない。
- InterfaceAdapters:
  - `NSEvent` など入力デバイス依存の `KeyTrigger` 正規化を担う。
- Application:
  - 現在状態（focus/mode）を使って Context を確定し、`ContextAction` を実行する。
  - `global`/`modal` は専用経路として扱う。

### 2.4 キーマップ管理層の固定

- `Layer 1: Intent Base Map`
  - 全体共通の標準割り当て。まずここを参照する。
- `Layer 2: Context/Mode Override`
  - Tree/Diagram/Modal など文脈差分のみ上書きする。
- `Layer 3: User Override`
  - ユーザー設定で最終上書きする。

解決ルール:

- 優先順は `User Override -> Context/Mode Override -> Intent Base Map`。
- `KeyTrigger` から Intent を決定する段階では、3層とも `Intent` のみを返す（ContextAction直結を禁止）。
- `ContextAction` の解決は Intent 決定後に行う。

## 3. 現状ベースライン（2026-02-26時点）

この計画では以下の現行挙動を変更前提にしない。

### 3.1 通常時（Canvas Hotkey Capture）

| KeyTrigger | 現行 ContextAction |
| --- | --- |
| `cmd+k` / `cmd+shift+p` | Command Palette を開く |
| `cmd+f` | Search UI を開く |
| `enter` | `addSiblingNode(.below)` |
| `opt+enter` | `addSiblingNode(.above)` |
| `cmd+enter` | `addChildNode` |
| `shift+enter` | Add Node Mode 選択ポップアップを開く |
| `delete` | `deleteFocusedNode` |
| `cmd+d` | `duplicateSelectionAsSibling` |
| `cmd+c` / `cmd+x` / `cmd+v` | copy/cut/paste subtree |
| `arrow` | `moveFocus` |
| `shift+arrow` | `extendSelection` |
| `cmd+arrow` | `moveNode` |
| `cmd+shift+arrow` | `nudgeNode` |
| `cmd+l` | Connect Node Selection を開始 |
| `ctrl+l` | `centerFocusedNode` |
| `opt+.` | `toggleFoldFocusedSubtree` |
| `cmd+z` / `cmd+shift+z` / `cmd+y` | undo/redo |
| `cmd+=` / `cmd+shift+=` / `cmd+shift+;` / `cmd+テンキー+` | zoom in |
| `cmd+-` | zoom out |

### 3.2 モーダル時

- Command Palette:
  - `enter`: 選択項目実行
  - `esc`: 閉じる
  - `up/down`: 選択移動
- Add Node Mode Selection:
  - `t` / `d`: Tree/Diagram 即時確定
  - `up/down`: 選択移動
  - `enter`: 確定
  - `esc`: キャンセル
- Connect Node Selection:
  - `arrow`: 候補移動
  - `enter`: 接続確定
  - `esc`: キャンセル
- Search:
  - `enter`: 次一致
  - `shift+enter`: 前一致
  - `esc`: 閉じる（必要に応じて `focusNode`）

## 4. Intent Primitive 定義と現状対応

本表は「操作プリミティブ対象」の Intent のみを扱う。
`cmd+k`（palette）/ `cmd+z`（history）/ `cmd+=`（zoom）などのグローバルショートカットは対象外とし、別レイヤーで管理する。

| Intent | 抽象意図 | Tree ContextAction（現状） | Diagram ContextAction（現状） | 導線状況 |
| --- | --- | --- | --- | --- |
| `add` | 新規対象を追加する | sibling/child の追加 | mode選択経由の追加 + `cmd+enter` の `addChildNode` は `addNode` へ正規化 | 実装済み |
| `edit` | 既存対象を編集する | テキスト編集開始/更新 | テキスト編集開始/更新 | 実装済み |
| `delete` | 対象を削除する | subtree削除（条件により複数） | ノード削除（条件により複数） | 実装済み |
| `toggleVisibility` | 可視状態を切替える | fold/unfold | 非対応（明示エラー） | Treeのみ実装 |
| `duplicate` | 対象を複製する | siblingとして複製 | 非対応（明示エラー） | Treeのみ実装 |
| `attach` | 添付情報を付与/更新する | 画像添付（Command Palette経由） | 画像添付（Command Palette経由） | ショートカット未割当 |
| `switchTargetKind` | 操作対象（node/edge）を切替える | 未実装（connect 導線は関連機能） | 未実装（connect 導線は関連機能） | 未実装 |
| `moveFocus` | フォーカス対象を移動する | `moveFocus` / `extendSelection` | `moveFocus` / `extendSelection` | 実装済み |
| `moveNode` | ノードを移動する | `moveNode` | `moveNode` | 実装済み |
| `nudgeNode` | ノードを最小単位で移動する | `nudgeNode` | `nudgeNode` | 実装済み |
| `search` | 対象を検索しジャンプする | Search UI | Search UI | 実装済み |
| `output` | 現在状態を出力する | 未定義 | 未定義 | 未実装 |
| `transform` | 異種構造へ変換する（例: tree <-> diagram） | エリアモード変換コマンドは存在するが専用導線未整備 | エリアモード変換コマンドは存在するが専用導線未整備 | 導線未整備 |
| `export` | 外部形式へ書き出す | 未定義 | 未定義 | 未実装 |
| `import` | 外部形式を取り込む | 未定義 | 未定義 | 未実装 |

補足:

- `transform` は `convertFocusedAreaMode` を中核に、Tree/Diagram 相互変換の専用導線として扱う。
- `attach/output/export/import` は実体機能の有無と無関係に Intent ID を先に固定する。

## 5. Command Palette 表現方針

- 同一 Intent でも Context 別に表示ラベルを分ける。
- 既存の `Noun: Verb` 形式は維持し、Context は Verb の具体化で吸収する。
- 例（`add`）:
  - Tree: `Node: Add Child` / `Node: Add Sibling Above` / `Node: Add Sibling Below`
  - Diagram: `Node: Add`
- 検索性維持のため、同義語は `searchTokens` に寄せ、表示ラベルは短く保つ。

## 6. 未実装 Intent の導線準備計画（実装は行わない）

### Phase 1: 意図辞書の固定（ドキュメント）

- Intent 一覧と定義文を本書で固定する。
- 現行 KeyTrigger から Intent への対応表は「操作プリミティブ対象」に限定して `docs/domain.md` のショートカット節へ追記可能な形で整理する。
- グローバルショートカット（palette/history/zoom など）は Intent 対象外として別管理であることを明記する。

### Phase 2: ルーティング境界の設計

- `IntentResolver`（仮）と `ContextActionResolver`（仮）の責務を分離する設計を定義する。
- `primitive` スコープの KeyTrigger 追加時にのみ、Intent 層を経由しない実装を禁止する。
- `global`/`modal` は `KeyTrigger` 追加時の必須ルートとして別管理する。
- `Intent Base Map` / `Context/Mode Override` / `User Override` の3層解決順を仕様化する。

### Phase 3: 未実装Intentの入口予約

- `switchTargetKind` は `node <-> edge` の操作対象切替として導線を予約する。
  - `edge` 対象時の `add` は接続作成（既存 connect 系）へ解決する方針で統一する。
- `transform` は Tree/Diagram 変換専用 Intent として、`convertFocusedAreaMode` へ到達する導線を予約する。
- `output` / `export` / `import` はショートカット未割当のまま、Command Palette で表示可能な導線を準備する設計とする。
- 実処理未実装時は no-op ではなく「未対応」を返すポリシーを採用する。

## 7. 受け入れ条件

- 既存ショートカット挙動を変えずに、操作プリミティブ対象ショートカットは Intent 単位で説明可能な状態になる。
- グローバルショートカット（palette/history/zoom 等）は Intent 対象外として、別レイヤーで説明可能な状態になる。
- Tree/Diagram で意味が変わる操作を「同一Intent・別ContextAction」として一貫表現できる。
- 未実装機能でも、将来追加時の入口（Intent/Palette/エラー契約）が先に定義されている。
- キーマップ変更機能を追加する際、個別モード直結ではなく `Intent` 中心の3層解決を崩さない。
