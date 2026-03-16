# VM 利用 skill 設計

## 目的

`Tart` を使った HotkeyCanvas の GUI 検証を skill 化する前に、権限要求の境界と再利用する入口を固定する。

この文書の焦点は次の 3 点。

- `setup/teardown` を薄い wrapper script に集約する
- UI 操作そのものは固定シナリオ化せず柔軟性を残す
- 対象 skill だけを git 追跡し、他の `.codex` 運用は崩さない

## この skill の責務

この skill は「VM 作業場を安定して立ち上げ、片付ける」ことを主責務にする。

skill が直接固定化しないもの:

- Add Node popup の遷移手順
- click 座標や key sequence の詳細
- 特定シナリオ専用の one-shot 検証フロー

skill が標準化するもの:

- worker VM の clone / start / readiness 確認
- 必要に応じた guest 準備と前提確認
- 必要に応じた HotkeyCanvas debug 起動
- 必要に応じた HotkeyCanvas debug の fresh restart
- 標準成果物の保存と VM 停止

## 権限方針

### 重要な前提

`Tart` を shell script で包んでも、Codex CLI の sandbox 制限そのものは消えない。
意味があるのは、承認の単位を low-level command 群から wrapper script や限定した `tart` subcommand 群へ寄せられる点にある。

### 許可対象の分け方

標準では repo 内 script を優先し、探索的な GUI 操作でだけ `tart` を直接使う。

- `setup/teardown`:
  - `scripts/vm/session_up.sh`
  - `scripts/vm/session_down.sh`
- 柔軟操作:
  - `tart exec`
  - `tart ip`
  - `scripts/vm/send_keys.sh`
  - `scripts/vm/send_vnc_keys.sh`
  - `scripts/vm/fetch_debug_state.sh`
  - `scripts/vm/capture_screen.sh`

慎重に扱う対象:

- `tart clone`
- `tart run`
- 既存 image / VM を破壊する操作

skill からは、削除系や image 更新系の操作を標準フローに含めない。

## wrapper script 方針

### setup

`scripts/vm/session_up.sh` は、既存 script を順に呼ぶ薄い orchestrator とする。
利用時の環境変数は、都度コマンド前置ではなく `export` して使う。

扱うオプション:

- `--clone`
- `--prepare-guest`
- `--install-appium`
- `--check-guest`
- `--start-app`

設計意図:

- VM 名、display mode、shared repo 設定を毎回ぶらさない
- 固定シナリオに寄せず、作業開始点だけ揃える
- `prepare_guest_image.sh` や `check_guest_setup.sh` の知識を毎回 skill 本文に書かない

### teardown

`scripts/vm/session_down.sh` は、停止前の標準成果物保存を optional にしてから VM を止める。

扱うオプション:

- `--capture-screen`
- `--save-health`
- `--save-sessions`
- `--collect-standard-artifacts`

artifact 採取は best-effort にする。理由は、app 側が既に落ちていても VM 停止まで失敗扱いにしたくないため。

## UI 操作の考え方

この skill は、シナリオ別 wrapper を増やさない。
GUI 検証では「その場で必要な操作を組み立てる」自由度を優先する。

標準的な使い分け:

- app 内での modifier を含む key 操作:
  - `scripts/vm/send_keys.sh`
- guest display を見ながらの key / mouse 操作:
  - `scripts/vm/send_vnc_keys.sh`
- 内部状態確認:
  - `scripts/vm/fetch_debug_state.sh`
- 見た目確認:
  - `scripts/vm/capture_screen.sh`
- app を fresh に戻したい時:
  - `scripts/vm/restart_hotkey_canvas_debug.sh`

必要なら `tart exec` で guest 内 command を直接実行する。

## 標準成果物

skill の完了時に、少なくとも次のいずれかを残せる状態にする。

- screenshot PNG
- debug-state JSON
- host 側 tart run log

保存先の標準:

- host log:
  - `.tmp/vm/<vm-name>/host/`
- host artifact:
  - `.tmp/vm/<vm-name>/artifacts/`

## 追跡方針

repo では `.codex` 全体を引き続き ignore しつつ、対象 skill のみ unignore する。

対象 path:

- `.codex/skills/vm-ui-check/`

この構成により、既存の個人用 `.codex` 運用は維持しつつ、team で共有したい skill だけを git 管理できる。

## skill 本文の最小要件

`SKILL.md` には詳細手順を詰め込みすぎない。
最低限必要なのは次だけ。

- この skill を使う状況
- `session_up.sh` / `session_down.sh` を先に使うこと
- 柔軟操作では `tart exec` と既存 `scripts/vm/*` を使うこと
- 成果物を残すこと
- 詳細はこの文書と VM testing 文書を参照すること
