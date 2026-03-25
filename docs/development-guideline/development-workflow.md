# 開発ワークフローと規約

この文書は、日常的な開発の進め方と、実装時に従うべき規約をまとめた正本です。
関連文書の一覧、役割、参照タイミング、変更タイミングは `AGENTS.md` を参照すること。

## 開発の進め方

- 実装前に、対象変更の影響範囲と必要なテストを整理する。
- 設計や挙動に変更がある場合は、先にテスト追加・更新方針を決める。
- バグ修正では、修正前に失敗する回帰テストを用意してから本実装へ進む。
- 変更後は `swift build`、`./scripts/lint_and_format.sh`、`./scripts/test_with_coverage.sh` を通し、差分に必要な検証が揃っていることを確認する。

## ビルド・テスト・開発コマンド

基本コマンド:

- `swift build`
- `swift test`
- `./scripts/bootstrap_periphery.sh`
- `./scripts/lint_and_format.sh`
- `./scripts/test_with_coverage.sh`
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
  - `as!` による強制ダウンキャストは禁止する（SwiftLint `force_cast` を `error` 扱い）。
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

### domain-doc アノテーション方針

- `Sources/Domain/Model` 配下で構造関係の抽出対象にしたい型には、宣言直前の `///` doc comment で `@domainDoc` アノテーションを付ける。
- 構造関係の抽出単位として扱う型には `/// @domainDoc entity` を付ける。
- ID 型がどのエンティティを識別するかを抽出器へ伝える場合は `/// @domainDoc identifierOf(TargetType)` を付ける。
- `@domainDoc` はコメント規約の例外ではなく `///` doc comment の一部として扱う。Quick Help 向けの説明も必要な場合は、同じ doc comment ブロック内で人間向け説明と `@domainDoc` を併記してよい。
- `domain-doc` 抽出器は保存プロパティの型推論を扱わない。抽出対象に含まれる Swift ファイルでは、保存プロパティに明示的な型アノテーションを付ける。
- `docs/specs/generated/domain-model-relations.md` と `docs/specs/generated/domain-model-relations.json` は `./scripts/generate_domain_docs.sh` の生成物なので手動編集しない。
- `Sources/Domain/Model` の構造、`@domainDoc` アノテーション、または抽出対象の型注釈を変更した場合は、同じ変更で `./scripts/generate_domain_docs.sh` と `./scripts/test_domain_docs.sh` を実行して生成物と抽出ルールを更新確認する。
- `@domainDoc` の追加要否に迷った場合は、「その型や識別子の対応が構造関係の把握に必要か」を基準に判断し、必要なら同じ変更で `docs/specs/domain.md` の説明も追従させる。

## テスト方針

- テスト配置と命名規則は `docs/specs/architecture.md` に従う。
- まず Domain の不変条件と UseCase の振る舞いを優先し、その後に adapter の変換と統合フローを確認する。
- `swift test` で再現できる UI 相当の回帰は、`Tests/InterfaceAdaptersTests/*UITests.swift` を追加・更新して、入力から UI 状態までの変化を検証する。
- バグ修正には必ず回帰テストを添える。
- 変更後は `./scripts/test_with_coverage.sh` を含む必要な検証を行い、変更 source 群に対するテストの妥当性を確認する。
- テスト戦略、`./scripts/test_with_coverage.sh` の運用、coverage しきい値の扱いは `docs/development-guideline/testing-guideline.md` を参照する。

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
