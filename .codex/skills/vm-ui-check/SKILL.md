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

必要に応じて次を付ける。

- VM clone が必要:
  - `--clone`
- guest 前提確認が必要:
  - `--prepare-guest`
  - `--check-guest`
- app 起動まで済ませたい:
  - `--start-app`
- 標準成果物を残して閉じたい:
  - `--collect-standard-artifacts`

## 柔軟操作の原則

UI 操作は固定 wrapper に閉じ込めない。
状況に応じて次を使い分ける。

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

## 成果物

少なくとも次のどちらかを残す。

- screenshot PNG
- debug-state JSON

host 側 log / artifact の標準保存先は `.tmp/vm/<vm-name>/` 配下。

## 詳細参照

詳細な運用判断が必要な時は次を読む。

- `../../../docs/development-guideline/vm-skill-design.md`
- `../../../docs/development-guideline/vm-ui-testing.md`
- `../../../docs/development-guideline/vm-ui-testing-troubleshooting.md`
