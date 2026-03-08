# Repository Guidelines

## Architecture Reference

`docs/specs/architecture.md` is the single source of truth for layer responsibilities, dependency direction, directory placement, naming conventions, and UI display flow rules.

## Domain Documentation

- `docs/specs/domain.md` documents domain-by-domain structure, services, usage, and invariants.
- When adding or changing domain models/services/commands/errors under `Sources/Domain/`, update `docs/specs/domain.md` in the same change.
- When changing application behavior that affects how domain services are used (for example command dispatch or service call flow), update the relevant usage sections in `docs/specs/domain.md`.

## Project Structure & Module Organization

Follow `docs/specs/architecture.md` for layer boundaries, dependency rules, and placement decisions.

## Build, Test, and Development Commands

Canonical commands:

- `cat docs/specs/architecture.md`: review constraints before coding.
- `cat docs/development-guideline/vm-ui-testing.md`: review the isolated macOS VM UI testing flow when working on GUI verification.
- `swift build`
- `swift test`
- `./scripts/bootstrap_periphery.sh`
- `git log --oneline`: inspect prior commit style.
- `find . -maxdepth 3 -type f`: verify expected scaffold files.

## Coding Style & Naming Conventions

- Language target: Swift.
- Use 4-space indentation and keep one primary type per file.
- Keep domain logic pure in `Domain/`; keep framework/API details in adapters.
- Naming rules are defined in `docs/specs/architecture.md`.
- Language policy:
  - Source code comments in `.swift` files must be written in English.
  - Documentation under `docs/` must be written in Japanese.
- Lint/type safety rules:
  - `Any` is prohibited (SwiftLint `custom_rules.no_any_type` as `error`).
  - Prefer concrete types, generics, or `any Protocol`.
  - Run lint with `./scripts/lint_and_format.sh` (Swift Package Plugin based; no global SwiftLint required).
  - `./scripts/lint_and_format.sh` also runs Periphery to detect unused declarations and redundant `public` accessibility.
  - Periphery is invoked with `--retain-codable-properties` to avoid flagging properties that are only used through synthesized `Codable` behavior.
  - Periphery is provisioned as a repo-local tool under `.tools/` via `./scripts/bootstrap_periphery.sh`, so contributors do not need a global `brew`/`mint` installation and local/CI can share the same fixed version.
  - The first bootstrap downloads Periphery from GitHub Releases, so `curl`, `unzip`, and network access are required once.
  - `./scripts/lint_and_format.sh` is a fix-and-verify command: it auto-formats what can be fixed mechanically, then exits non-zero only for remaining manual issues.
  - When CI uses `./scripts/lint_and_format.sh`, also verify that no diff remains after execution so auto-fixed changes do not silently pass without being committed.

## Comment Policy

- Use `///` doc comments for symbols that should surface in LSP/Quick Help.
- Add a short file-header comment at the top of each Swift file describing:
  - Why the file exists (background/context).
  - What responsibility the file owns.
- Add `///` on public/internal types with a one-line responsibility summary.
- Add `///` on functions with purpose plus `- Parameters`, `- Returns`, `- Throws` when relevant.
- Add `///` on stored properties only when intent is not obvious from naming.
- Use `// MARK: ...` for logical sections in larger files.
- Keep comments short and maintainable; avoid comments that merely restate the code.

## Testing Guidelines

- Test placement and naming rules are defined in `docs/specs/architecture.md`.
- Prioritize domain invariants and use-case behavior first, then adapter mapping and integration flows.
- For UI-like regression scenarios on `swift test`, add/update `Tests/InterfaceAdaptersTests/*UITests.swift` to cover input-to-UI-state behavior changes.
- Add regression tests with each bug fix.
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

## Debug State API (Local Development)

Use the debug-state API to fetch live application state from external tools (for example Codex CLI) during local development.

- Enable API at launch (DEBUG build only):
  - `swift run HotkeyCanvasApp -- --enable-debug-state-api --debug-state-port=8750 --debug-state-token=codex-demo-token`
- Notes:
  - API binds to `127.0.0.1` only.
  - If `--debug-state-token` is omitted, a random token is generated and printed to app logs.
  - Startup now waits for listener readiness; port conflicts are reported as startup failure.

Endpoints (all require `Authorization: Bearer <token>`):

- Health:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/health`
- Session list:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/sessions`
- Single session state:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/sessions/<session-id>/state`
- Domain catalog for a session:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/sessions/<session-id>/domains`
- Domain-specific state:
  - `curl -s -H 'Authorization: Bearer codex-demo-token' http://127.0.0.1:8750/debug/v1/sessions/<session-id>/domains/<domain-id>`
  - Available `domain-id` values:
    - `d1-canvas-graph-editing`
    - `d2-focus-and-selection`
    - `d3-area-layout`
    - `d4-tree-layout`
    - `d5-shortcut-catalog`
    - `d6-fold-visibility`
    - `d7-area-mode-membership`

Typical workflow:

1. Start app with `--enable-debug-state-api`.
2. Call `/debug/v1/sessions` to get active `sessionID`.
3. Call `/debug/v1/sessions/<session-id>/domains` to discover domain endpoints.
4. Call `/debug/v1/sessions/<session-id>/domains/<domain-id>` for target domain state.
5. Call `/debug/v1/sessions/<session-id>/state` when full graph/UI snapshot is needed.
