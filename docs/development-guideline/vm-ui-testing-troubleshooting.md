# VM UI テスト実測メモ

## 目的

`Tart --no-graphics + guest VNC + debug-state API` で HotkeyCanvas を自律操作したときに、実際に詰まった点と回避策を残す。

このメモの対象は、2026-03-08 に `Diagram area の 2 nodes + 3 edges + screenshot` を通した時の知見。

## 先に結論

- host 無干渉で進める標準は `Tart --no-graphics` に固定する
- 画面取得と入力は guest VNC に寄せる
- 状態確認は必ず debug-state API で併用する
- `tart exec` 経由の入力自動化は `tart-guest-agent` の TCC を前提に考える
- 空キャンバスでは最初の 1 手が特殊なので、Diagram シナリオでも Tree bootstrap node を経由する方が安定する

## 実際に詰まった点

### 1. `--vnc` / `--vnc-experimental` は host 側 viewer を開く

- Tart の viewer や macOS Screen Sharing が host 前面に出る
- 要件の「host 作業に干渉しない」と相性が悪い
- 標準運用では使わず、`no-graphics + guest VNC` に寄せる

### 2. `no-graphics` だけでは visual verification にならない

- app 自体は起動していても、guest display を取らない限り見た目を確認できない
- guest の `screencapture` は TCC や tart guest agent の状態に左右されやすい
- 実運用では host 側の `vncdotool capture` を正本にする

### 3. TCC の主体は `osascript` ではなく `tart-guest-agent`

- `tart exec` で動かした `swift` や `osascript` に権限を付けても不十分だった
- 実際の event injection / AppleEvents は `tart-guest-agent` として評価される
- seed 後に `bootstrap_tcc_permissions.sh` で DB を揃える前提が必要

### 4. `osascript` だけで権限問題は解けない

- `System Events` にキーストロークを送る前に Automation / Accessibility の許可が必要
- 未許可状態では `osascript` 自体が止まる
- 「許可ダイアログを osascript で押す」は循環参照になりやすい

### 5. app 起動直後は少し待たないと入力が落ちる

- `start_hotkey_canvas_debug.sh` の直後にすぐ入力すると反映しないケースがあった
- 実測では最初に `pause:2.0` を置くと安定した

### 6. canvas に click しないと key が入らないことがある

- guest display 上で app window が見えていても、入力先が安定しないことがあった
- `move:500:350` + `click:1` を先に入れると安定した

### 7. 空キャンバスでは `shift+enter` が期待通りの popup にならない

- 空キャンバスでいきなり `shift+enter` を送ると、Diagram popup ではなく Tree node 作成に流れることがあった
- この挙動は実装上の初期状態と相性があり、最初の 1 node は Tree bootstrap と割り切る方が安定した
- その後に `shift+enter -> d -> enter` で Diagram area を作る流れは安定した

### 8. Add Node popup は `down` より `d` が安定した

- popup 選択で `down -> enter` は期待通りに Diagram へ移らないケースがあった
- `d -> enter` の方が再現性が高かった
- 今の scripts はこの経路を採用している

### 9. node 追加直後は text editing 中なので `esc` が必要

- node 作成直後にそのまま次の shortcut を送ると、文字入力や no-op になることがあった
- 次の node 追加や Connect Mode 前に `esc` を挟むと安定した

### 10. `vncdotool` の修飾キー名は `cmd` ではなく `super` が通った

- `cmd-enter` / `cmd-l` は VNC 経路で不安定だった
- 実測で通ったのは `super-enter` と `super-l`
- 成功した意味は次の通り
  - `super-enter`: Diagram area の focused node から新しい Diagram node を追加
  - `super-l`: Connect Mode を開く

### 11. debug-state の総 node 数だけを見ると誤判定しやすい

- 空キャンバスから始めると Tree bootstrap node が 1 つ残る
- そのため成功時でも `total nodeCount = 3` になり得る
- 判定は「Diagram area に属する node / edge 数」で見る方が正しい

### 12. guest screenshot に VNC 由来のバナーが写ることがある

- `Your screen is being controlled`
- `Viewer has disconnected`
- これは host 側 viewer を開いているのではなく、guest 側 Screen Sharing の状態表示
- host 無干渉要件の破綻ではないが、見た目検証ではノイズになる

## 安定した実行パターン

空キャンバスから `Diagram 2 nodes + 3 edges` を作る時は、次の考え方が安定した。

1. app 再起動後に少し待つ
2. canvas を click して入力先を固定する
3. `shift+enter -> esc` で最初の Tree node を bootstrap する
4. `shift+enter -> d -> enter` で Diagram area の最初の node を作る
5. `esc -> super-enter` で同じ Diagram area に 2 個目を追加する
6. `esc -> super-l -> enter` を必要回数繰り返して edge を増やす
7. 最後に screenshot と debug-state を両方保存する

## 実測で通ったシナリオ

`capture_diagram_multi_edge.sh --edge-count 3` が通った時の VNC 入力列は次だった。

```text
pause:2.0
move:500:350
click:1
pause:1.0
shift+enter
pause:1.0
esc
pause:0.8
shift+enter
pause:1.0
d
pause:0.7
enter
pause:1.5
esc
pause:0.8
super+enter
pause:1.5
esc
pause:0.8
super+l
pause:1.0
enter
pause:1.5
super+l
pause:1.0
enter
pause:1.5
```

この結果、debug-state 上は次を満たした。

- total nodes: 3
- total edges: 3
- diagram nodes: 2
- diagram edges: 3

## 次回の作業前チェック

- `check_guest_setup.sh` で `agent-appleevents`, `real-listenevent`, `real-postevent` が `ok` か確認する
- `start_worker.sh` は `HOTKEY_VM_DISPLAY_MODE=no-graphics` を使う
- 最初の入力前に canvas click を入れる
- Diagram シナリオでも空キャンバスなら Tree bootstrap を前提にする
- 成否は screenshot だけでなく debug-state でも確認する
