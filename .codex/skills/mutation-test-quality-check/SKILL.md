---
name: mutation-test-quality-check
description: ユーザーが指定したテスト範囲に対して、現実的で一時的なミューテーションをプロダクションコードへ加え、既存テストがそのデグレを検知できるかを調べ、テスト品質を評価して改善提案を返す。テストの妥当性確認、欠陥のないテストの発見、回帰検知力の点検、テスト追加方針の整理をしたいときに使う。
---

# Mutation Test Quality Check

この skill は、テストの量ではなく回帰検知力を点検するために使う。
プロダクションコードへ現実的な一時変更を 1 件ずつ加え、既存テストが落ちるかを見て、弱いテストや欠落ケースを特定する。

## 手順

1. 対象範囲を確定する
- ユーザーが対象のテスト範囲を指定していなければ、最初に確認する。
- 範囲はテスト target / テスト識別子 / source file / feature 名のいずれでもよい。
- 期待する保証内容も確認する。
  - 例: 正常系だけでなく不変条件、境界値、Undo/Redo、ViewModel 反映まで守りたい。

2. 対象コードと対応テストを対応付ける
- `swift test list` で候補テスト識別子を確認する。
- 対象 source が絞れるなら `Sources/...` と `Tests/...` の対応を先に整理する。
- HotkeyCanvas では Domain と Application の保証を優先する。
- 変更単位が大きい場合は、一度に広げすぎず最小単位へ分割する。

3. 現実的なミューテーション候補を選ぶ
- `references/realistic-mutations.md` を使い、実装者が現実にやりがちな変更だけを候補にする。
- いじわるな破壊ではなく、次のような変更を優先する。
  - 条件の反転や境界値のずれ
  - 更新対象の取り違え
  - 一部副作用や整合処理の抜け
  - filter / map / sort 条件の取り違え
  - Undo/Redo や派生状態の更新漏れ
- 1 回の調査で扱う mutation は 3 件前後を上限の目安にし、数より妥当性を優先する。

4. 変更前の安全を確保する
- dirty worktree を前提に、対象ファイルの既存差分を壊さない。
- mutation は必ず `apply_patch` で最小差分として入れる。
- mutation を重ねず、1 件ずつ適用して結果を採る。
- 各 mutation の実行後は必ず元に戻してから次へ進む。

5. baseline を確認する
- mutation を入れる前に、元コードのまま対象テストを走らせる。
- baseline が pass していることを確認できた場合だけ、mutation 調査へ進む。
- baseline が fail した場合は `killed / survived` を判定せず、先に失敗原因の切り分けを優先する。

6. mutation ごとに focused test を実行する
- HotkeyCanvas では次を優先する。
  - `./scripts/test_with_coverage.sh --filter <test-id> --focus-source <Sources/...>`
  - 必要に応じて `swift test --filter <test-id>`
- 既存テストが mutation を検知して落ちたら `killed`、通ってしまったら `survived` と記録する。
- 失敗理由が mutation と無関係なら、その mutation は無効として扱い、別の現実的な mutation に差し替える。

7. テスト品質を評価する
- `references/reporting-rubric.md` を使い、単なる kill 数ではなく保証の質で判断する。
- 特に次を分けて評価する。
  - テストが主要な振る舞いを直接保証しているか
  - たまたま別アサーションで落ちただけではないか
  - 正常系しかなく、異常系や境界値が欠けていないか
  - Domain の不変条件や Application の調停結果まで見ているか
- survived mutation があれば、どの挙動が未保証かを具体化する。

8. 結果を報告する
- 対象範囲、試した mutation、結果、評価、推奨対応をまとめる。
- mutation の有無だけでなく、なぜその mutation を選んだかを説明する。
- 推奨対応は「追加すべきテスト」「弱い assertion の強化」「不要なテストの整理」に分ける。
- 調査が終わった時点で、プロダクションコードは必ず元の状態へ戻しておく。

## ガードレール

- テストコードではなく、原則としてプロダクションコードを mutate する。
- 永続化しない一時変更として扱い、最終的な差分に mutation を残さない。
- 明らかに仕様外の壊し方は避ける。
  - 例: 無関係な `fatalError` の注入、意味のない乱数化、型を壊すだけの変更
- repo ルールに反する optional や fallback を安易に持ち込まない。
- 既存の未コミット変更と衝突する場合は、そのまま進めずに対象の切り分けを優先する。
- 目的は mutation を通すことではなく、足りないテストを見つけて改善方針を出すこととする。

## HotkeyCanvas での実行メモ

- 開発ガイドの正本:
  - `../../../docs/development-guideline/development-workflow.md`
- レイヤー責務の正本:
  - `../../../docs/specs/architecture.md`
- よく使う確認:
  - `swift test list`
  - `./scripts/test_with_coverage.sh --filter <test-id> --focus-source <Sources/...>`
  - `swift build`

## 詳細参照

必要な時だけ次を読む。

- 現実的な mutation の選び方:
  - `references/realistic-mutations.md`
- 評価と報告の rubric:
  - `references/reporting-rubric.md`
