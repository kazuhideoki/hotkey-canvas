# テストガイドライン

この文書は、テスト戦略、追加・更新の判断基準、coverage 運用、`./scripts/test_with_coverage.sh` の使い方をまとめた正本です。
日常的な開発フローや他の規約は `docs/development-guideline/development-workflow.md` を参照すること。

## 目的

- 変更箇所に必要なテストを過不足なく追加し、回帰を早い段階で検出できる状態を保つ。
- Domain / Application の主要分岐で未テストを残さず、変更が重要ロジックに与える影響を明確にする。
- `./scripts/test_with_coverage.sh` を使って、「今回触った source 群に対して十分なテストが当たっているか」を継続的に確認する。

## テスト戦略

- テスト配置と命名規則は `docs/specs/architecture.md` に従う。
- Swift Testing の `@Test("...")` 表示名は日本語で記述し、関数名は既存どおり英語の識別子として保つ。
- `@Test("...")` の表示名は原則として振る舞いベースの短い文にし、`条件 + 結果` を基本形とする。
- 表示名の第一候補の文型は `〜のとき、〜する` とし、仕様語として重要な操作名だけ `undo` や `addNode` のように残してよい。
- `正常系` `異常系` `ケース1` のような抽象名や、実装の呼び出し事実だけを書く表示名は避ける。
- まず Domain の不変条件と UseCase の振る舞いを優先し、その後に adapter の変換と統合フローを確認する。
- `swift test` で再現できる UI 相当の回帰は、`Tests/InterfaceAdaptersTests/*UITests.swift` を追加・更新して、入力から UI 状態までの変化を検証する。
- バグ修正には必ず回帰テストを添える。

## 変更種別ごとの期待値

- 機能追加では、追加した分岐や不変条件を直接保証するテストを用意する。
- 挙動変更では、既存テストの期待値更新だけで済ませず、新しい仕様差分を表すテストを追加する。
- バグ修正では、修正前に失敗する回帰テストを先に用意してから本実装へ進む。
- リファクタリングでも、影響範囲の主要経路を通るテストを維持し、coverage を不必要に下げない。

## 実行手順

- 変更内容に応じて、まず追加・修正したテストだけを `--filter` で実行する。
- そのうえで `--focus-source` または `--changed-since` を使い、変更 source 群にテストが当たっているか確認する。
- 最終確認では `swift build`、`./scripts/lint_and_format.sh`、`./scripts/test_with_coverage.sh` を通す。

## Coverage 運用

- テストカバレッジの確認には `./scripts/test_with_coverage.sh` を使う。
- `./scripts/test_with_coverage.sh` は通常はそのまま `swift test --enable-code-coverage` を実行し、coverage JSON に載っている `Sources/` の line coverage を集計する。
- しきい値定義の正本は `scripts/test_with_coverage_threshold.json` とし、`./scripts/test_with_coverage.sh` はそこから読み込んで判定する。
- ビルド成果物や module cache が怪しい場合のみ `--clean` を付けて `swift package clean` を先に実行する。
- `--focus-source` または `--changed-since` を付けた場合は、focus 対象 source file ごとにしきい値判定する。
- focus 指定がない場合は、レイヤー集計 (`LAYER ...`) に対してしきい値判定する。
- script は coverage しきい値チェック結果を `COVERAGE_CHECK=PASS|FAIL` として出力する。

## `test_with_coverage.sh` オプション

- `--filter` に渡す値はテストファイル名ではなく `swift test list` に表示されるテスト識別子を使う。識別子が1件もヒットしない場合、script はエラー終了する。
- `--focus-source` は `Sources/...` のパス断片を複数指定できる。該当 source file 単位の coverage と、その合算 coverage を `FOCUS ...` / `FOCUSED_SOURCE_LINE_COVERAGE` として表示する。
- `--changed-since <git-ref>` は有効な git ref を必須とし、`git diff <git-ref>...HEAD -- Sources` に加えて staged / unstaged / untracked の `Sources/` 変更も focus 対象へ追加する。差分 coverage を厳密に測るものではなく、「今回触った source 群が追加テストでどれだけ通っているか」をざっくり確認する用途で使う。
- focus 対象が1件も見つからない場合は `FOCUS_MATCHERS=NO_MATCH` と `FOCUSED_SOURCE_LINE_COVERAGE=NO_MATCH` を表示する。

## 典型例

- 変更全体の coverage を見る: `./scripts/test_with_coverage.sh`
- stale build を疑うので clean してから見る: `./scripts/test_with_coverage.sh --clean`
- 追加したテスト候補を列挙する: `swift test list | rg '^DomainTests\.'`
- 追加したテストだけを回す: `./scripts/test_with_coverage.sh --filter DomainTests.test_validation_invalidOperations_throwExpectedErrors`
- 追加したテストが対象 source に当たっているか見る: `./scripts/test_with_coverage.sh --filter DomainTests.test_validation_invalidOperations_throwExpectedErrors --focus-source Sources/Domain/Service/CanvasGraphCRUDService.swift`
- 未コミット変更を含めた現在作業中の source 群を見る: `./scripts/test_with_coverage.sh --changed-since HEAD`
- ベースブランチとの差分に現在の作業中変更も足して見る: `./scripts/test_with_coverage.sh --changed-since origin/main`

## 受け入れ基準

- 変更箇所に必要なテストが追加されていること。
- 追加したテストを `--filter` で実行したときに、変更 source 群の coverage が基準を満たすこと。
- 特に Domain / Application の主要分岐で未テストを残さないこと。
- 既存 coverage を不必要に下げないこと。

## Baseline としきい値

- 2026-03-07 時点の reported-source baseline は以下。
- Total: `58.41%` (`11694/20021`)
- `Domain`: `93.22%` (`3039/3260`)
- `Application`: `87.92%` (`5939/6755`)
- `InterfaceAdapters`: `27.14%` (`2716/10006`)
- 当面のしきい値は `scripts/test_with_coverage_threshold.json` に定義する。2026-03-08 時点の内容は以下。
- focus 指定なしでは `LAYER Domain >= 80%`、`LAYER Application >= 70%` を適用する。
- focus 指定ありでは `Sources/Domain/` 配下の各 file を `85%` 以上、`Sources/Application/` 配下の各 file を `75%` 以上とする。
- focus 指定ありでは `Sources/InterfaceAdapters/Input/`、`Sources/InterfaceAdapters/Persistence/`、`Sources/InterfaceAdapters/Output/ViewModel/`、`Sources/InterfaceAdapters/Output/DebugState/` 配下の各 file を `70%` 以上とする。
- `Sources/InterfaceAdapters/Output/SwiftUI/`、`Sources/App/`、`Sources/Infrastructure/` は当面 hard gate 対象外とし、機能追加・変更時は回帰テストの有無をレビューで確認する。

## CI での扱い

- CI に組み込む場合も、最初は coverage の表示と記録のみに留める。
- warning や gate の強制は、運用が安定してから段階的に検討する。
