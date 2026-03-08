# リポジトリガイドライン

## アーキテクチャ参照

`docs/specs/architecture.md` は、レイヤー責務、依存方向、ディレクトリ配置、命名規則、UI 表示フロー規約の正本です。

## ドメイン文書

- `docs/specs/domain.md` は、ドメインごとの構造、サービス、利用箇所、不変条件を整理した正本です。
- `Sources/Domain/` 配下の model / service / command / error を追加・変更した場合は、同じ変更で `docs/specs/domain.md` を更新すること。
- アプリケーション挙動の変更により Domain サービスの使われ方が変わる場合は、`docs/specs/domain.md` の関連利用節も更新すること。

## プロジェクト構造とモジュール構成

レイヤー境界、依存ルール、配置判断は `docs/specs/architecture.md` に従うこと。

## ビルド・テスト・開発コマンド

基本コマンド:

- `cat docs/specs/architecture.md`: 実装前に設計制約を確認する。
- `cat docs/development-guideline/vm-ui-testing.md`: GUI 検証時の隔離 macOS VM UI テスト運用を確認する。
- `swift build`
- `swift test`
- `./scripts/bootstrap_periphery.sh`
- `git log --oneline`: 既存コミットの要約スタイルを確認する。
- `find . -maxdepth 3 -type f`: 想定どおりにファイルが配置されているか確認する。

## コーディングスタイルと命名規則

- 対象言語は Swift。
- インデントは 4 スペースとし、1 ファイル 1 主体型を基本とする。
- Domain ロジックは `Domain/` に純粋に保ち、フレームワークや API の詳細は adapter 側へ隔離する。
- 命名規則は `docs/specs/architecture.md` に従う。
- 言語方針:
  - `.swift` ファイル内のコメントは日本語で記述する。
  - 既存の英語コメントは一括変換を必須としないが、関連機能の追加・修正時に触れた箇所は可能な限り同じ変更で日本語へ更新する。
  - `docs/` 配下のドキュメントは日本語で記述する。
- Lint / 型安全ルール:
  - `Any` の使用は禁止する（SwiftLint `custom_rules.no_any_type` を `error` 扱い）。
  - 抽象化が必要な場合も、具体型、ジェネリクス、`any Protocol` を優先する。
  - lint は `./scripts/lint_and_format.sh` を使う（Swift Package Plugin ベースで、グローバルな SwiftLint は不要）。
  - `./scripts/lint_and_format.sh` は Periphery も実行し、未使用宣言や冗長な `public` アクセス指定を検出する。
  - Periphery には `--retain-codable-properties` を付け、合成 `Codable` だけで使われるプロパティの誤検出を防ぐ。
  - Periphery は `./scripts/bootstrap_periphery.sh` により `.tools/` 配下へ repo ローカルに導入する。これにより、開発者はグローバルな `brew` / `mint` を前提にせず、CI と同じ固定バージョンを使える。
  - 初回 bootstrap では GitHub Releases から Periphery をダウンロードするため、`curl`、`unzip`、ネットワーク接続が一度だけ必要になる。
  - `./scripts/lint_and_format.sh` は fix-and-verify 型のコマンドであり、機械的に直せる箇所は自動整形したうえで、手修正が必要な問題だけを非ゼロ終了で返す。
  - CI で `./scripts/lint_and_format.sh` を使う場合は、実行後に差分が残っていないことも確認し、自動修正分が未コミットのまま通過しないようにする。

## コメント方針

- LSP / Quick Help に出すべきシンボルには `///` の doc comment を付ける。
- 各 Swift ファイルの先頭には、そのファイルについて短いヘッダーコメントを置く。
  - なぜそのファイルが存在するのか（背景・文脈）
  - どの責務を担当するのか
- `public` / `internal` の型には、責務を 1 行で要約する `///` を付ける。
- 関数には、目的に加えて必要に応じて `- Parameters`、`- Returns`、`- Throws` を含む `///` を付ける。
- 保存プロパティには、名前だけでは意図が読み取りづらい場合に限って `///` を付ける。
- 大きめのファイルでは論理区切りとして `// MARK: ...` を使う。
- コメントは処理内容の説明だけでなく、意図、背景、その設計や分岐が必要な理由まで説明すること。
- 複雑な処理では、読み手が意図をコードから逆算しなくて済むように、重要な手順、分岐、不変条件の確認ごとに行レベルコメントを入れること。
- コメント量を機械的に減らすより、設計意図や背景を保つことを優先する。ただし保守不能な長文化は避ける。
- 自明なコードをそのまま言い換えるだけで、追加の意図や理由を含まないコメントは避ける。

## テスト方針

- テスト配置と命名規則は `docs/specs/architecture.md` に従う。
- まず Domain の不変条件と UseCase の振る舞いを優先し、その後に adapter の変換と統合フローを確認する。
- `swift test` で再現できる UI 相当の回帰は、`Tests/InterfaceAdaptersTests/*UITests.swift` を追加・更新して、入力から UI 状態までの変化を検証する。
- バグ修正には必ず回帰テストを添える。
- テストカバレッジの確認には `./scripts/test_with_coverage.sh` を使う。
- `./scripts/test_with_coverage.sh` は通常はそのまま `swift test --enable-code-coverage` を実行し、coverage JSON に載っている `Sources/` の line coverage を集計する。
- ビルド成果物や module cache が怪しい場合のみ `--clean` を付けて `swift package clean` を先に実行する。
- 機能改修やバグ修正では、まず追加・修正したテストだけを `--filter` で実行し、そのうえで `--focus-source` もしくは `--changed-since` で「該当箇所付近」の coverage を確認する。
- `--filter` に渡す値はテストファイル名ではなく `swift test list` に表示されるテスト識別子を使う。識別子が1件もヒットしない場合、script はエラー終了する。
- `--focus-source` は `Sources/...` のパス断片を複数指定できる。該当 source file 単位の coverage と、その合算 coverage を `FOCUS ...` / `FOCUSED_SOURCE_LINE_COVERAGE` として表示する。
- `--changed-since <git-ref>` は有効な git ref を必須とし、`git diff <git-ref>...HEAD -- Sources` に加えて staged / unstaged / untracked の `Sources/` 変更も focus 対象へ追加する。差分 coverage を厳密に測るものではなく、「今回触った source 群が追加テストでどれだけ通っているか」をざっくり確認する用途で使う。
- focus 対象が1件も見つからない場合は `FOCUS_MATCHERS=NO_MATCH` と `FOCUSED_SOURCE_LINE_COVERAGE=NO_MATCH` を表示する。
- 典型例:
  - 変更全体の coverage を見る: `./scripts/test_with_coverage.sh`
  - stale build を疑うので clean してから見る: `./scripts/test_with_coverage.sh --clean`
  - 追加したテスト候補を列挙する: `swift test list | rg '^DomainTests\.'`
  - 追加したテストだけを回す: `./scripts/test_with_coverage.sh --filter DomainTests.test_validation_invalidOperations_throwExpectedErrors`
  - 追加したテストが対象 source に当たっているか見る: `./scripts/test_with_coverage.sh --filter DomainTests.test_validation_invalidOperations_throwExpectedErrors --focus-source Sources/Domain/Service/CanvasGraphCRUDService.swift`
  - 未コミット変更を含めた現在作業中の source 群を見る: `./scripts/test_with_coverage.sh --changed-since HEAD`
  - ベースブランチとの差分に現在の作業中変更も足して見る: `./scripts/test_with_coverage.sh --changed-since origin/main`
- カバレッジは受け入れ判断の補助指標として扱い、開発初期フェーズでは閾値未満を即エラーにする hard gate は導入しない。
- 当面の受け入れ基準は「変更箇所に必要なテストが追加されていること」「追加したテストを `--filter` で実行したときに、変更 source 群の coverage が極端に低くないこと」「特に Domain / Application の主要分岐で未テストを残さないこと」「既存 coverage を不必要に下げないこと」とする。
- 2026-03-07 時点の reported-source baseline は以下。
  - Total: `58.41%` (`11694/20021`)
  - `Domain`: `93.22%` (`3039/3260`)
  - `Application`: `87.92%` (`5939/6755`)
  - `InterfaceAdapters`: `27.14%` (`2716/10006`)
- 当面の目安は、`Domain` は `80%` 以上、`Application` は `70%` 前後以上を維持対象として扱い、`InterfaceAdapters` は UI 相当の変更点に対する回帰テスト追加を優先する。
- CI に組み込む場合も、最初は coverage の表示と記録のみに留め、運用が安定してから warning や gate を段階的に検討する。

## Debug State API（ローカル開発）

ローカル開発時に、Codex CLI などの外部ツールからアプリの現在状態を取得するために debug-state API を使う。

- 起動時に API を有効化する（DEBUG build のみ）:
  - `swift run HotkeyCanvasApp -- --enable-debug-state-api --debug-state-port=8750 --debug-state-token=codex-demo-token`
- 注意:
  - API は `127.0.0.1` にのみ bind する。
  - `--debug-state-token` を省略すると、ランダムトークンを生成して app log に出力する。
  - 起動処理は listener の ready を待つ。ポート競合がある場合は起動失敗として扱う。

エンドポイント一覧（すべて `Authorization: Bearer <token>` が必要）:

- ヘルスチェック:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/health`
- セッション一覧:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/sessions`
- 単一セッションの状態:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/sessions/<session-id>/state`
- セッションごとのドメイン一覧:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/sessions/<session-id>/domains`
- ドメイン別状態:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/sessions/<session-id>/domains/<domain-id>`
  - 利用可能な `domain-id`:
    - `d1-canvas-graph-editing`
    - `d2-focus-and-selection`
    - `d3-area-layout`
    - `d4-tree-layout`
    - `d5-shortcut-catalog`
    - `d6-fold-visibility`
    - `d7-area-mode-membership`

典型的な利用手順:

1. `--enable-debug-state-api` を付けて app を起動する。
2. `/debug/v1/sessions` を呼び、現在の `sessionID` を取得する。
3. `/debug/v1/sessions/<session-id>/domains` を呼び、参照可能な domain endpoint を確認する。
4. 対象 domain の状態が必要なら `/debug/v1/sessions/<session-id>/domains/<domain-id>` を呼ぶ。
5. グラフ全体や UI 全体の snapshot が必要なら `/debug/v1/sessions/<session-id>/state` を使う。
