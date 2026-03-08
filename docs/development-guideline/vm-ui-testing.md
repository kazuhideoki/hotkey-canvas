# VM UI テスト運用ガイド

## 目的

ホストユーザーの画面や入力に干渉せず、agent 専用の macOS VM 内で HotkeyCanvas の GUI を検証する。

このガイドの対象は、2026-03-08 時点で実際に通った最小構成です。

- VM: `Tart --no-graphics` で起動した macOS VM
- 画面操作: host から guest の `VNC`
- スクリーンショット: host 側 `vncdotool capture`
- 内部状態確認: guest 内 `debug-state API`
- アプリ起動: guest 内 `tart exec ... swift run HotkeyCanvasApp`

## この構成を採る理由

- host のキーボードやマウスには触れず、guest display にだけ入力を送れる
- 見た目の確認と内部状態確認を分離できる
- `Docker 上の macOS` のような非現実的な前提を置かずに済む
- Tart 内蔵の `--vnc` 系が host 側 viewer を開く問題を避けられる

## 前提

- Apple silicon host
- host に `tart`
- host に `vncdotool`
- base image または golden image がある
- guest に `swift`, `curl`
- guest の Screen Sharing / VNC login が有効
- 実用運用では guest に full Xcode を入れ、必要な TCC 許可を事前付与する

## 使用スクリプト

- `scripts/vm/create_golden_image.sh`
- `scripts/vm/clone_worker.sh`
- `scripts/vm/start_worker.sh`
- `scripts/vm/stop_worker.sh`
- `scripts/vm/prepare_guest_image.sh`
- `scripts/vm/bootstrap_tcc_permissions.sh`
- `scripts/vm/check_guest_setup.sh`
- `scripts/vm/start_hotkey_canvas_debug.sh`
- `scripts/vm/send_keys.sh`
- `scripts/vm/send_vnc_keys.sh`
- `scripts/vm/fetch_debug_state.sh`
- `scripts/vm/capture_screen.sh`
- `scripts/vm/capture_diagram_multi_edge.sh`

## 基本フロー

### 1. golden image を作る

```bash
HOTKEY_VM_GOLDEN_IMAGE=hotkey-canvas-golden \
scripts/vm/create_golden_image.sh
```

### 2. worker VM を複製して起動する

```bash
HOTKEY_VM_GOLDEN_IMAGE=hotkey-canvas-golden \
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/clone_worker.sh

HOTKEY_VM_NAME=hotkey-canvas-agent \
HOTKEY_VM_DISPLAY_MODE=no-graphics \
HOTKEY_VM_SHARED_REPO_MODE=rw \
scripts/vm/start_worker.sh
```

`HOTKEY_VM_SHARED_REPO_MODE=rw` を付けると、host の repo が guest に `virtiofs` 共有される。
既定では `guest workspace = /Volumes/My Shared Files/repo` として扱う。

### 3. guest を整備する

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/prepare_guest_image.sh --install-appium

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/bootstrap_tcc_permissions.sh

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/check_guest_setup.sh
```

Appium は将来の自動化経路として残しているが、最小フローでは必須ではない。

`bootstrap_tcc_permissions.sh` の前に、guest へ VNC 接続した状態で一度だけ以下を完了させる。

- `tart-guest-agent` が `System Events` を制御しようとした時の `Allow`
- Privacy & Security に誘導された場合の `tart-guest-agent` event injection 許可

この seed が必要な理由は、`tart exec` で起動した入力処理の TCC subject が `osascript` や `swift` ではなく `tart-guest-agent` として評価されるため。

### 4. HotkeyCanvas を guest 内で起動する

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/start_hotkey_canvas_debug.sh
```

debug-state API の疎通確認:

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/fetch_debug_state.sh /debug/v1/health
```

## VNC で UI を操作する

### スクリーンショット取得

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/capture_screen.sh .tmp/vm-artifacts/guest-screen.png
```

このスクリプトは guest の `screencapture` を使わず、host 側の VNC capture を使う。
そのため、host UI ではなく guest display だけを撮れる。
標準では接続先は guest 自身の `$(tart ip <vm-name>):5900` になる。

### 任意入力の例

`vncdotool` を直接使えば、guest display にだけ入力を流せる。

例: Add Node Mode Selection を開いて Tree node を追加する

```bash
cat > /tmp/vnc-tree-node.txt <<'EOF'
key shift-enter
pause 0.5
key t
pause 0.5
key enter
pause 1
capture /absolute/path/to/repo/.tmp/vm-artifacts/tree-node.png
EOF

vncdotool \
  -u admin \
  -p admin \
  -s "$(tart ip hotkey-canvas-agent)::5900" \
  /tmp/vnc-tree-node.txt
```

この操作後、`scripts/vm/fetch_debug_state.sh` で `nodeCount` や `graph.nodes` を確認する。

modifier key を含む入力は `vncdotool` で不安定な場合がある。`cmd` 系ショートカットを多用する場面では、guest 側で `CGEvent` を送る補助手段を使う前提で設計する。

例: `CGEvent` ベースで `cmd+enter` と `cmd+l` を送る

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/send_keys.sh cmd+enter pause:0.5 cmd+l pause:0.3 enter
```

例: guest VNC 経由で Add Node popup を操作する

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/send_vnc_keys.sh move:500:350 click:1 pause:0.5 shift+enter pause:0.5 d pause:0.3 enter
```

例: Diagram 2 nodes + 3 edges を作ってスクリーンショットを保存する

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/capture_diagram_multi_edge.sh \
  --edge-count 3 \
  --output .tmp/vm-artifacts/diagram-multi-edge.png \
  --state-output .tmp/vm-artifacts/diagram-multi-edge-state.json
```

空キャンバスから始める場合、このスクリプトは Tree node を 1 つ bootstrap してから Diagram area を作る。
そのため総 `nodeCount` は 3 でも、検証対象としては Diagram area の 2 nodes + 複数 edges を満たしていれば成功とみなす。

## 推奨アサーション

- 見た目:
  - `capture_screen.sh` または `vncdotool capture` の PNG
- 内部状態:
  - `fetch_debug_state.sh /debug/v1/sessions`
  - `fetch_debug_state.sh /debug/v1/sessions/<session-id>/state`

見た目だけ、または内部状態だけで判定しない。両方で照合する。

## 既知の制約

- `no-graphics` 単体では visual verification に向かない
- visual verification では `no-graphics` を guest VNC と組み合わせて使う
- guest の `screencapture` は TCC や tart guest agent の状態次第で期待通りに取れない
- modifier key を含む入力は `vncdotool` で不安定な場合がある
- `tart-guest-agent` の TCC は `user DB` と `system DB` の両方を確認する必要がある
- `bootstrap_tcc_permissions.sh` は初回 seed の後追い整形であり、最初の macOS 許可操作そのものは置き換えられない
- `--vnc` / `--vnc-experimental` は Tart が host 側 viewer を開くため、host 無干渉運用の標準にはしない
- Appium/mac2 はこの repo ではまだ標準運用にしていない

## 後片付け

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/stop_worker.sh
```
