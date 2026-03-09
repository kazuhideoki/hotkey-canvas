---
name: vm-ui-check
description: Use when checking HotkeyCanvas behavior inside a Tart VM, especially when you need setup and teardown to be standardized but want the actual UI operations to stay flexible. This skill prepares the VM session, uses tart exec and scripts/vm helpers for exploratory interaction, and records artifacts before shutdown.
---

# VM UI Check

この skill は、Tart VM 上で HotkeyCanvas の GUI 挙動を探索的に確認する時に使う。
固定シナリオを増やすのではなく、`setup/teardown` を安定化し、途中操作は柔軟に組み立てる。

## 先に使う入口

- 起動準備:
  - `scripts/vm/session_up.sh`
- 後片付け:
  - `scripts/vm/session_down.sh`

よく使う入口:

- 新規 worker を作って app も起動する:
  - `export HOTKEY_VM_NAME=<worker-name>`
  - `export HOTKEY_VM_SHARED_REPO_MODE=rw`
  - `export HOTKEY_VM_DISPLAY_MODE=no-graphics`
  - `scripts/vm/session_up.sh --clone --check-guest --start-app`
- 既存 worker を再利用して app を起動する:
  - `export HOTKEY_VM_NAME=<worker-name>`
  - `export HOTKEY_VM_SHARED_REPO_MODE=rw`
  - `export HOTKEY_VM_DISPLAY_MODE=no-graphics`
  - `scripts/vm/session_up.sh --check-guest --start-app`

必要に応じて次を付ける。

- VM clone が必要:
  - `--clone`
  - 新規 worker を作る時だけ付ける。`--clone` は clone だけでなく start まで含む
- guest 前提確認が必要:
  - `--prepare-guest`
  - `--check-guest`
- app 起動まで済ませたい:
  - `--start-app`
- app を fresh に起動し直したい:
  - `scripts/vm/restart_hotkey_canvas_debug.sh`
- 標準成果物を残して閉じたい:
  - `--collect-standard-artifacts`

## 柔軟操作の原則

UI 操作は固定 wrapper に閉じ込めない。
状況に応じて次を使い分ける。

debug-state を使うなら、先に `--start-app` または `scripts/vm/start_hotkey_canvas_debug.sh` で app を起動しておく。
途中で操作が崩れた時は、`scripts/vm/restart_hotkey_canvas_debug.sh` で app を fresh に戻してから再試行する。

- guest 内 command 実行:
  - `tart exec`
- modifier を含む key 操作:
  - `scripts/vm/send_keys.sh`
- VNC 経由の key / mouse 操作:
  - `scripts/vm/send_vnc_keys.sh`
- debug-state 取得:
  - `scripts/vm/fetch_debug_state.sh`
- screenshot 取得:
  - `scripts/vm/capture_screen.sh`

空キャンバスから tree と diagram を両方作る時は、次の順が安定しやすい。

- canvas を click して入力先を固定する
- `shift+enter -> esc` で tree node を bootstrap する
- `shift+enter -> d -> enter` で diagram area の最初の node を作る
- `super+enter` で同じ diagram area に node を追加する

## 成果物

可能なら `screenshot PNG` と `debug-state JSON` の両方を残す。
app が起動しなかった場合でも、最低でも host 側 log の場所は残す。

標準保存先:

- host log:
  - `.tmp/vm/<vm-name>/host/`
- host artifact:
  - `.tmp/vm/<vm-name>/artifacts/`

`session_down.sh --collect-standard-artifacts` が長く待つ場合は、artifact 採取の完了を確認してから `tart stop "$HOTKEY_VM_NAME"` で明示停止してよい。

## 詳細参照

必要な時だけ次を読む。

- 権限境界と wrapper 方針:
  - `../../../docs/development-guideline/vm-skill-design.md`
- 通常の VM 手順:
  - `../../../docs/development-guideline/vm-ui-testing.md`
- 詰まった時の復旧:
  - `../../../docs/development-guideline/vm-ui-testing-troubleshooting.md`
