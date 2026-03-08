# VM Scripts

このディレクトリは、agent 専用 macOS VM を使って HotkeyCanvas を検証するための最小スクリプト群です。

現在の運用前提は `Tart --no-graphics + guest VNC + tart exec + debug-state API` です。  
SSH や guest-local workspace 前提の未検証ラッパーは置かず、実際に通した構成だけを残しています。

## 前提

- Apple silicon 環境
- host に `tart`
- host に `vncdotool`
- guest に `swift`, `curl`
- guest の full Xcode は golden image 側で事前整備すること
- guest の Screen Sharing / VNC login が有効であること
- guest の TCC は `user DB` と `system DB` を跨ぐので、初回 seed 後に `scripts/vm/bootstrap_tcc_permissions.sh` で揃えること

## 主な環境変数

- `HOTKEY_VM_GOLDEN_IMAGE`
  - clone 元の image 名
- `HOTKEY_VM_NAME`
  - worker VM 名
- `HOTKEY_VM_GUEST_USER`
  - guest 内ホームディレクトリ解決に使うユーザー名。既定値は `admin`
- `HOTKEY_VM_GUEST_WORKSPACE`
  - guest 側の作業ディレクトリ。未指定時は shared repo をそのまま使う
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
- `HOTKEY_VM_VNC_PORT`
  - VNC port。既定値は `5900`
- `HOTKEY_VM_VNC_USERNAME`
  - VNC username。既定値は `admin`
- `HOTKEY_VM_VNC_PASSWORD`
  - VNC password。既定値は `admin`

## 推奨構成

- golden image は `Xcode + Screen Sharing + TCC 許可済み` を前提にする
- 起動は `HOTKEY_VM_DISPLAY_MODE=no-graphics` を標準にする
- 画面接続は Tart 内蔵 viewer ではなく guest 側の VNC を使う
- スクリーンショットは guest の `screencapture` ではなく、host 側の `vncdotool` を使う
- `vnc` / `vnc-experimental` は Tart が host 側 viewer を開くため、通常運用では使わない

## Golden Image 作成

```bash
HOTKEY_VM_GOLDEN_IMAGE=hotkey-canvas-golden \
scripts/vm/create_golden_image.sh
```

起動後に guest を整備する:

```bash
HOTKEY_VM_NAME=hotkey-canvas-golden \
HOTKEY_VM_DISPLAY_MODE=no-graphics \
HOTKEY_VM_SHARED_REPO_MODE=rw \
scripts/vm/start_worker.sh

HOTKEY_VM_NAME=hotkey-canvas-golden \
scripts/vm/prepare_guest_image.sh --install-appium

HOTKEY_VM_NAME=hotkey-canvas-golden \
scripts/vm/bootstrap_tcc_permissions.sh

HOTKEY_VM_NAME=hotkey-canvas-golden \
scripts/vm/check_guest_setup.sh
```

`bootstrap_tcc_permissions.sh` の前に、guest へ VNC 接続した状態で一度だけ `tart-guest-agent` の macOS 権限を seed する。

- `System Events` を制御する prompt が出たら `Allow`
- Privacy & Security が開いたら `tart-guest-agent` の event injection を有効化
- guest VNC login が未設定なら `admin / admin` など固定の認証情報を整備する

## 最小フロー

```bash
HOTKEY_VM_GOLDEN_IMAGE=hotkey-canvas-golden \
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/clone_worker.sh

HOTKEY_VM_DISPLAY_MODE=no-graphics \
HOTKEY_VM_SHARED_REPO_MODE=rw \
HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/start_worker.sh

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/start_hotkey_canvas_debug.sh

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/fetch_debug_state.sh /debug/v1/health

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/capture_screen.sh .tmp/vm-artifacts/guest-screen.png

HOTKEY_VM_NAME=hotkey-canvas-agent \
scripts/vm/stop_worker.sh
```

## 残すスクリプト

- `common.sh`
  - 共通環境変数と Tart/VNC ヘルパー
- `create_golden_image.sh`
  - base image から local golden image を作る
- `clone_worker.sh`
  - golden image から作業 VM を複製する
- `start_worker.sh`
  - worker VM を標準では `no-graphics` で起動する
- `stop_worker.sh`
  - worker VM を停止する
- `prepare_guest_image.sh`
  - guest のディレクトリ準備と Appium 導入補助を行う
- `bootstrap_tcc_permissions.sh`
  - tart-guest-agent / osascript の TCC 行を user DB / system DB に揃える
- `check_guest_setup.sh`
  - Xcode / Appium / mac2 / TCC 行の前提確認を行う
- `start_hotkey_canvas_debug.sh`
  - guest 内で `swift run HotkeyCanvasApp -- --enable-debug-state-api ...` を起動する
- `send_keys.sh`
  - guest 内で CGEvent を使ってキーストロークを送る
- `send_vnc_keys.sh`
  - host 側 `vncdotool` で guest に plain key / popup navigation / mouse move / click を送る
- `fetch_debug_state.sh`
  - debug-state API を guest 内から叩いて host に返す
- `capture_screen.sh`
  - host 側 `vncdotool` で guest の VNC display を PNG 保存する
- `capture_diagram_multi_edge.sh`
  - Diagram 2 nodes + 複数 edge + screenshot を one-shot で作る
  - 空キャンバス時は Tree node を 1 つ bootstrap してから Diagram area を育てる

## 補足

- `prepare_guest_image.sh --install-appium` は `npm` がある guest にだけ使える。
- Appium/mac2 は将来の自動化経路として残しているが、この README の最小フローは Appium に依存しない。
- `tart exec` から起動したプロセスの TCC subject は実際には `tart-guest-agent` になる。`osascript` だけを許可しても不十分。
- `bootstrap_tcc_permissions.sh` は初回承認を完全自動化するものではない。最初の `Allow` と Privacy & Security の切り替えは guest 側で一度だけ必要。
- `--vnc` / `--vnc-experimental` は Tart 自身が host の VNC viewer を開くので、host 無干渉要件とは相性が悪い。
- `capture_diagram_multi_edge.sh` は seed 済み guest を前提にする。未完了だと event injection prompt で止まる。
