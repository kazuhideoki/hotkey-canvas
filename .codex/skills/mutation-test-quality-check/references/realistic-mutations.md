# 現実的な Mutation パターン

この資料は、「普段の機能開発で起こりうる修正ミス」を mutation として表現するための基準である。
mutation を増やすこと自体が目的ではない。対象機能の責務に対して妥当な変更だけを選ぶ。

## 選定原則

- 1 つの mutation で 1 つの意味だけを崩す。
- 実装者の勘違い、境界値ミス、更新漏れ、対象取り違えを優先する。
- コンパイルを壊す mutation は避ける。
- 無関係な層を巻き込む mutation は避ける。
- 仕様そのものを書き換えるのではなく、仕様に対する実装ミスを模倣する。

## 優先パターン

### 1. 条件反転

使いどころ:
- 分岐の正負が重要なロジック
- 表示可否、選択可否、 validation、 guard 条件

例:

```swift
if shouldFold {
```

を

```swift
if !shouldFold {
```

へ変える。

見るべき点:
- 正常系だけでなく、反対側の分岐を確認するテストがあるか
- 単に件数だけでなく、対象要素まで assertion しているか

### 2. 境界値ずれ

使いどころ:
- index、件数、長さ、座標、 range、しきい値

例:

```swift
if children.count >= 2 {
```

を

```swift
if children.count > 2 {
```

へ変える。

見るべき点:
- 0 / 1 / ちょうど境界 / 境界超え のケースが揃っているか

### 3. 対象取り違え

使いどころ:
- selected / focused / parent / sibling / current area のように近い概念が複数ある箇所

例:

```swift
targetNodeID = focusedNodeID
```

を

```swift
targetNodeID = selectedNodeID
```

へ変える。

見るべき点:
- 「何かが更新された」ではなく「正しい対象が更新された」を見ているか
- 同名に近い ID や state を区別する assertion があるか

### 4. filter 条件の緩み・厳しすぎ

使いどころ:
- collection の抽出、検索、削除対象選定、表示対象選定

例:

```swift
items.filter { $0.parentID == nodeID }
```

を

```swift
items.filter { $0.parentID != nodeID }
```

または

```swift
items.filter { $0.areaID == nodeID }
```

へ変える。

見るべき点:
- 件数一致だけでなく内容一致を確認しているか
- 想定外要素が混ざらないことを見ているか

### 5. 並び順の取り違え

使いどころ:
- sort、layout、表示順、 traversal 順

例:

```swift
nodes.sorted { $0.order < $1.order }
```

を

```swift
nodes.sorted { $0.order > $1.order }
```

へ変える。

見るべき点:
- 順序まで見ているテストがあるか
- 集合比較だけで済ませていないか

### 6. 副作用の抜け

使いどころ:
- graph mutation 後の再 layout、 selection 正規化、 viewport intent、通知発火

例:
- 状態更新はするが、関連する再計算や side effect を呼ばない

見るべき点:
- 中核 state だけでなく派生結果も見ているか
- UseCase が orchestration を担う箇所で、 domain state 以外の結果も保証しているか

### 7. Undo/Redo 情報の欠落

使いどころ:
- `ApplyResult` や undo token を返す処理

例:
- 状態は変えるが `undoToken` を返さない
- 一部コマンドだけ undo 情報を取り忘れる

見るべき点:
- 「変更後 state」だけでなく undo 可能性まで確認しているか

### 8. 片側だけ更新

使いどころ:
- 双方向関連、 index と実体、 graph と selection、 model と view model

例:
- node は追加するが parent 側の children を更新しない
- domain state は更新するが view model 反映が抜ける

見るべき点:
- 関連する両側の整合を見ているか
- 片側の assertion だけで満足していないか

## 避けるべき Mutation

- 無関係な `fatalError` や `preconditionFailure` を入れる
- ランダム値や時刻依存を混ぜる
- 大量のコード削除で何が効いたか分からなくする
- repo ルールに反する optional / fallback を無目的に追加する
- 1 つの mutation に複数の意味変更を詰め込む

## HotkeyCanvas で優先しやすい観点

- Domain:
  - 不変条件
  - graph 整合性
  - layout 前提条件
- Application:
  - stage 順序
  - `ApplyResult` の内容
  - Undo/Redo と side effect
- InterfaceAdapters:
  - translator の変換条件
  - view model の派生表示

## 迷ったときの判断

- その mutation が PR レビューで「ありそう」と感じるなら採用候補。
- その mutation が「こんな壊し方は誰もしない」と感じるなら却下。
- mutation が survived しても、仕様上重要でない挙動なら優先度を下げてよい。
