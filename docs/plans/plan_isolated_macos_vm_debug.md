# Agent 専用 macOS VM UI デバッグ環境計画

## 1. 目的

- コーディングエージェントに、Web でいう Playwright に近い体験を与える。
- ホストユーザーの作業画面や入力へ干渉せず、隔離された macOS GUI 環境で UI 検証を自律実行できるようにする。
- 失敗時にスクリーンショット、録画、アクセシビリティツリー、内部状態を回収し、必要ならその時点の VM 状態を保存して再開できるようにする。

## 2. 非目標

- Docker コンテナの中で macOS GUI を直接動かすこと。
- ホスト側のデスクトップセッション上で Appium / Accessibility / XCUITest を直接実行すること。
- 1 台の macOS 実行環境に複数の UI セッションを多重起動して高密度並列化すること。

## 3. 背景整理

- 欲しい体験の本質は「真の headless」ではなく、「エージェント専用の GUI セッションをホスト UI から隔離して持つこと」である。
- macOS アプリ自動化では、Appium Mac2 / XCUITest / Accessibility は GUI セッション前提で動くため、ブラウザの完全 headless と同じ構成にはならない。
- したがって目標は、`headless-like な隔離 GUI セッション` を VM 内に持ち、それを Codex CLI から遠隔操作することと定義する。

## 4. 固定方針

### 4.1 採用技術

- macOS の隔離実行は Apple silicon 上の `Virtualization.framework` 系を前提にする。
- 直近の実装基盤は `Tart` を第一候補とし、必要が出たら後段で自前ラッパーへ移行可能な構造にする。
- `1 agent = 1 macOS VM = 1 UI automation session` を固定方針とする。
- 同一 VM 内で複数の Appium UI セッションを並列実行しない。並列化が必要なら VM を増やす。

### 4.2 隔離ポリシー

- UI 入力とスクリーンショットは VNC 経由で guest display にだけ流す。
- ホスト側では Codex CLI が VM の起動、停止、VNC 操作、debug-state 取得を行う。
- ホストのマウス、キーボード、アクティブアプリ、アクセシビリティ権限を UI 検証のために利用しない。

### 4.3 作業コピー方針

- 現在の最小実装では、ホストの作業ツリーを `virtiofs` 共有し、guest から直接参照して起動する。
- 将来 guest-local working copy に寄せる余地はあるが、現時点の repo scripts は共有 repo 直参照を正本とする。

### 4.4 検証方針

- 視覚的な UI 操作と観測は `VNC + vncdotool` を主経路にする。
- 内部状態の真偽確認は既存の debug-state API を併用し、見た目確認と状態確認を分離する。
- `Appium Mac2` は将来の拡張経路として扱い、現時点の最小運用には含めない。

## 5. 候補比較

| 方式 | UI 非干渉 | Codex からの自律操作 | 実現性 | 判定 |
| --- | --- | --- | --- | --- |
| Docker 上で macOS GUI を動かす | 低い | 低い | 低い | 不採用 |
| ホストのデスクトップでそのまま Appium を実行 | 低い | 中 | 高い | 不採用 |
| 同一 Mac 上の macOS VM を agent 専用に使う | 高い | 高い | 高い | 採用 |
| 別 Apple silicon Mac 上の macOS VM worker を使う | 高い | 高い | 高い | 将来拡張 |

補足:

- 今回の要求は「ホストユーザーの作業への UI 干渉を避けること」なので、まずは同一 Mac 上の macOS VM で要件を満たせる。
- CPU / RAM 競合までは避けない前提でよいなら、別ホスト worker は初期導入の必須要件ではない。

## 6. 推奨アーキテクチャ

### 6.1 コンポーネント

- Host Controller
  - Codex CLI
  - VM lifecycle 管理スクリプト
  - コード同期スクリプト
  - アーティファクト回収スクリプト
- Guest Worker VM
  - macOS
  - Xcode / Command Line Tools
  - Appium 3
  - `appium-mac2-driver`
  - `ffmpeg`
  - SSH サーバー
  - 検証補助スクリプト
- App Under Test
  - HotkeyCanvas
  - `--enable-debug-state-api` 付きで起動

### 6.2 責務分離

- Host Controller の責務
  - VM の clone / boot / stop / reset
  - guest へのコード同期
  - guest コマンドの遠隔実行
  - スクリーンショット、録画、ログ、debug-state JSON の回収
- Guest Worker VM の責務
  - ビルド
  - アプリ起動
  - Appium server 起動
  - UI 操作
  - ローカルログ収集
- HotkeyCanvas の責務
  - 既存の debug-state API で内部状態を出す

## 7. 実行モデル

### 7.1 Golden Image

- 初回だけ手作業またはセットアップスクリプトで guest image を作る。
- image には以下を事前投入する。
  - Xcode
  - Appium / Mac2 driver / `ffmpeg`
  - Accessibility / Screen Recording / Full Disk Access など必要権限
  - 検証用ローカルユーザー
  - 必要なら署名用証明書、開発用キーチェーン設定
  - SSH 有効化
- この image を `golden image` とし、各ジョブは clone して使い捨てる。

### 7.2 ジョブ実行

1. Host で agent 専用 VM を clone して起動する。
2. guest-local な作業ディレクトリへコード同期する。
3. guest 内で `swift build` または必要なビルドを実行する。
4. guest 内で HotkeyCanvas を debug-state API 有効で起動する。
5. guest 内で Appium server を起動する。
6. Codex CLI が guest の Appium endpoint に対して UI 操作を行う。
7. 必要に応じて debug-state API を照会し、UI と内部状態を照合する。
8. 成否に応じてスクリーンショット、録画、ログ、JSON を回収する。
9. 失敗時は VM snapshot を保存し、成功時は VM を破棄または clean snapshot へ戻す。

### 7.3 Headless-like の意味

- guest 内では GUI セッションが存在する。
- ただしその GUI は VM の表示面に閉じており、ホストユーザーのデスクトップ操作には影響しない。
- Playwright の headless browser と厳密同一ではないが、`agent 専用・非干渉・再現可能` という目的に対しては実質的に同等とみなす。
- 視覚確認を伴う運用では `--no-graphics` ではなく `--vnc` または `--vnc-experimental` を標準にする。

## 8. 観測とアサーション

### 8.1 UI 観測

- Appium Mac2 で以下を取得する。
  - スクリーンショット
  - アクセシビリティツリー
  - 要素属性
  - 入力操作結果

### 8.2 内部状態観測

- 既存の debug-state API を guest 内で有効化する。
- Codex CLI は以下のどちらかで state を取得する。
  - guest 内で `curl` 実行
  - SSH port forward 経由で host から取得
- UI 上の見え方だけでなく、Domain / Application 状態の整合も確認する。

### 8.3 失敗時保存物

- Appium スクリーンショット
- 画面録画
- アプリログ
- debug-state JSON
- 失敗時 snapshot 名

## 9. 実装フェーズ

### Phase 1: 調査と方針固定

- 本計画書で完了。
- Docker ではなく macOS VM を採用する。
- 同一 Mac 上の local VM を初期ターゲットにする。

### Phase 2: ベース設計と運用境界の固定

- 追加するスクリプト責務を定義する。
  - `scripts/vm/create_golden_image.sh`
  - `scripts/vm/clone_worker.sh`
  - `scripts/vm/start_worker.sh`
  - `scripts/vm/stop_worker.sh`
  - `scripts/vm/prepare_guest_image.sh`
  - `scripts/vm/check_guest_setup.sh`
  - `scripts/vm/start_hotkey_canvas_debug.sh`
  - `scripts/vm/fetch_debug_state.sh`
  - `scripts/vm/capture_screen.sh`
- guest 側のディレクトリ規約を決める。
  - shared repo: `/Volumes/My Shared Files/repo`
  - `/Users/admin/artifacts`
  - `/Users/admin/logs`
- debug-state API のポート、認証トークン受け渡し方法を決める。

### Phase 3: 最小実装

- 1 台の VM を Codex CLI から起動できる。
- VNC-backed display で guest 画面を保存できる。
- shared repo を guest から参照して HotkeyCanvas を起動できる。
- VNC 入力と debug-state API を併用して 1 つの簡単な UI シナリオを実行できる。
- debug-state API を取得してアサーションできる。
- スクリーンショットを回収できる。

### Phase 4: 失敗再現性の強化

- VM snapshot 保存 / 復元を自動化する。
- 録画、ログ、debug-state の収集を標準化する。
- 失敗時に復元可能な job bundle を作る。

### Phase 5: 将来拡張

- 複数 VM への水平展開
- 別 Apple silicon worker への切り出し
- Orchard などの VM 管理基盤導入

## 10. 受け入れ条件

- ホストユーザーが通常作業をしていても、UI 自動化がホスト画面や入力へ干渉しない。
- Codex CLI が自力で VM を起動し、アプリを起動し、UI シナリオを完走できる。
- 失敗時にスクリーンショットと debug-state を必ず回収できる。
- 1 ジョブ終了後に clean な初期状態へ戻せる。
- ホスト上で Appium やアクセシビリティ操作を直接実行しない。

## 11. 現時点の推奨判断

- まずは `Tart + local macOS VM + guest-local workspace + Appium Mac2 + debug-state API` を最小構成として進める。
- `shared directory でホスト作業ツリーをそのまま触る` 構成は避ける。
- `別ホスト worker` は、UI 非干渉ではなく計算資源競合まで避けたくなった時点で導入する。

## 12. 参考

- Docker Desktop on Mac
  - https://docs.docker.com/desktop/features/networking/
  - https://docs.docker.com/desktop/troubleshoot-and-support/faqs/macfaqs/
- Apple Virtualization
  - https://developer.apple.com/documentation/virtualization/running-macos-in-a-virtual-machine-on-apple-silicon
  - https://developer.apple.com/videos/play/wwdc2022/10002/
  - https://developer.apple.com/videos/play/wwdc2023/10007/
- Appium Mac2 Driver
  - https://github.com/appium/appium-mac2-driver
- Tart
  - https://tart.run/
  - https://tart.run/quick-start/
  - https://tart.run/faq/
  - https://tart.run/orchard/quick-start/
