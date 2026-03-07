# VM Scripts

このディレクトリは、agent 専用 macOS VM を使って HotkeyCanvas を検証するためのスクリプト群です。

## 前提

- Apple silicon 環境
- host に `tart`, `rsync`, `ssh`
- guest に `swift`, `curl`
- Appium / Xcode / TCC は golden image 側で事前整備すること

## 主な環境変数

- `HOTKEY_VM_GOLDEN_IMAGE`
  - clone 元の image 名
- `HOTKEY_VM_NAME`
  - worker VM 名
- `HOTKEY_VM_SSH_USER`
  - guest のログインユーザー
- `HOTKEY_VM_GUEST_WORKSPACE`
  - guest 側の作業ディレクトリ
- `HOTKEY_VM_APPIUM_PORT`
  - guest 内 Appium port
- `HOTKEY_VM_APPIUM_BASE_PATH`
  - Appium base path。既定値は `/wd/hub`
- `HOTKEY_VM_DEBUG_STATE_PORT`
  - debug-state API port
- `HOTKEY_VM_DEBUG_STATE_TOKEN`
  - debug-state API bearer token
- `HOTKEY_VM_DISPLAY_MODE`
  - `vnc`, `vnc-experimental`, `no-graphics`, `gui`
- `HOTKEY_VM_SHARED_REPO_MODE`
  - `ro` または `rw`
- `HOTKEY_VM_BASE_IMAGE_SOURCE`
  - golden image 作成元の remote Tart image
- `HOTKEY_VM_TART_RUN_EXTRA_ARGS`
  - `tart run` に渡す追加引数

## 推奨構成

- golden image は `Xcode + appium + appium-mac2-driver + ffmpeg + TCC 許可済み` を前提にする
- 起動は `HOTKEY_VM_DISPLAY_MODE=vnc` か `vnc-experimental` を推奨する
- `no-graphics` は build/debug-state 用途に限定し、視覚確認には使わない

## Golden Image 作成

```bash
HOTKEY_VM_GOLDEN_IMAGE=hotkey-canvas-golden \
scripts/vm/create_golden_image.sh
```

起動後に guest を整備する:

```bash
HOTKEY_VM_NAME=hotkey-canvas-golden \
HOTKEY_VM_DISPLAY_MODE=vnc \
HOTKEY_VM_SHARED_REPO_MODE=rw \
scripts/vm/start_worker.sh

HOTKEY_VM_NAME=hotkey-canvas-golden \
scripts/vm/prepare_guest_image.sh --install-appium

HOTKEY_VM_NAME=hotkey-canvas-golden \
scripts/vm/check_guest_setup.sh
```

## 最小フロー

```bash
HOTKEY_VM_GOLDEN_IMAGE=hotkey-canvas-golden \
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/clone_worker.sh

HOTKEY_VM_DISPLAY_MODE=vnc \
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/start_worker.sh

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/sync_workspace.sh

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/start_hotkey_canvas_debug.sh

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/start_appium_server.sh

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/fetch_debug_state.sh /debug/v1/health

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/capture_screen.sh .tmp/vm-artifacts/guest-screen.png

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/collect_artifacts.sh
```

## 補足

- `scripts/vm/check_guest_setup.sh` は Xcode / Appium / mac2 / Accessibility trust の前提確認に使う。
- `scripts/vm/capture_screen.sh` は shared repo に guest display の PNG を保存する。
- `scripts/vm/open_vnc_display.sh` は VNC 表示前提の運用メモを出す。
- Appium session の作成自体は、Codex CLI 側から HTTP で行う想定です。
- `scripts/vm/run_guest_command.sh` を使えば guest 内で任意コマンドを実行できます。
- TCC 付与は macOS 制約上、golden image へ一度手動で焼き込む前提です。
