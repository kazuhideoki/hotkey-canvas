# VM UI テスト運用ガイド

## 目的

ホストユーザーの画面や入力に干渉せず、agent 専用の macOS VM 内で HotkeyCanvas の GUI を検証する。

このガイドの対象は、2026-03-08 時点で実際に通った最小構成です。

- VM: `Tart` で起動した macOS VM
- 画面操作: host から `VNC`
- スクリーンショット: host 側 `vncdotool capture`
- 内部状態確認: guest 内 `debug-state API`
- アプリ起動: guest 内 `tart exec ... swift run HotkeyCanvasApp`

## この構成を採る理由

- host のキーボードやマウスには触れず、guest display にだけ入力を送れる
- 見た目の確認と内部状態確認を分離できる
- `Docker 上の macOS` のような非現実的な前提を置かずに済む

## 前提

- Apple silicon host
- host に `tart`
- host に `vncdotool`
- base image または golden image がある
- guest に `swift`, `curl`
- 実用運用では guest に full Xcode を入れ、必要な TCC 許可を事前付与する

## 使用スクリプト

- `scripts/vm/create_golden_image.sh`
- `scripts/vm/clone_worker.sh`
- `scripts/vm/start_worker.sh`
- `scripts/vm/stop_worker.sh`
- `scripts/vm/prepare_guest_image.sh`
- `scripts/vm/check_guest_setup.sh`
- `scripts/vm/start_hotkey_canvas_debug.sh`
- `scripts/vm/fetch_debug_state.sh`
- `scripts/vm/capture_screen.sh`

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
HOTKEY_VM_DISPLAY_MODE=vnc \
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
scripts/vm/check_guest_setup.sh
```

Appium は将来の自動化経路として残しているが、最小フローでは必須ではない。

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

## 推奨アサーション

- 見た目:
  - `capture_screen.sh` または `vncdotool capture` の PNG
- 内部状態:
  - `fetch_debug_state.sh /debug/v1/sessions`
  - `fetch_debug_state.sh /debug/v1/sessions/<session-id>/state`

見た目だけ、または内部状態だけで判定しない。両方で照合する。

## 既知の制約

- `no-graphics` は visual verification に向かない
- guest の `screencapture` は TCC や tart guest agent の状態次第で期待通りに取れない
- modifier key を含む入力は `vncdotool` で不安定な場合がある
- Appium/mac2 はこの repo ではまだ標準運用にしていない

## 後片付け

```bash
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/stop_worker.sh
```
