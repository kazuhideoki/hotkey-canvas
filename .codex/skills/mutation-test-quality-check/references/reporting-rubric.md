# 評価と報告の Rubric

この資料は、mutation 実行結果をどう評価し、どう報告するかの基準である。
単純な kill 数ランキングにはしない。保証したい挙動に対して、テストが妥当な強さを持つかで判断する。

## 報告フォーマット

### 1. 対象範囲

- ユーザーが指定した feature / source / test scope
- 今回の保証対象
  - 例: graph mutation の整合性
  - 例: Undo/Redo の成立
  - 例: view model への反映

### 2. 試した Mutation

各 mutation について次を記載する。

- 変更したファイル
- 変更内容
- その mutation を選んだ理由
- 実行したテスト
- 結果:
  - `killed`
  - `survived`
  - `invalid`

`invalid` の条件:
- mutation と無関係な理由で失敗した
- コンパイルや test harness が壊れただけ
- 1 つの意味変更として不適切だった

### 3. 評価

以下の 4 軸で短く評価する。

- 振る舞い保証:
  - 主要な仕様を直接見ているか
- 境界値保証:
  - 端の条件を押さえているか
- 誤更新検知:
  - 間違った対象更新や更新漏れを検知できるか
- 回帰検知力:
  - 実装ミスが入った時に高確率で落ちるか

## 評価ランク

### High

- 重要な realistic mutation の大半が killed
- 落ち方が本質的で、偶然の assertion ではない
- 正常系だけでなく境界値や関連 state も見ている

### Medium

- 中核挙動の mutation は killed できる
- ただし境界値、派生 state、誤更新検知の一部が弱い
- 軽い追加テストや assertion 強化で改善できる

### Low

- 重要な realistic mutation が複数 survived
- 正常系の happy path しか見ていない
- 件数や nil でしか見ておらず、対象や内容を保証していない

## 推奨対応の出し方

推奨対応は次の順で出す。

1. 追加すべき回帰テスト
- survived mutation に直結する最小のテストを提案する。

2. 強化すべき assertion
- 件数確認を内容確認へ変える
- state の一部確認を整合確認へ広げる
- 成功可否だけでなく副作用や派生結果も見る

3. 不要または弱すぎるテストの整理
- 何を守るか不明なテスト
- mutation に対して何も効かない重複テスト

## まとめ方の型

```text
対象:
- {scope}

実施した mutation:
- {file}: {change} / 理由: {why} / 結果: killed|survived|invalid

総合評価:
- High | Medium | Low
- 根拠: {guarantee strength}

不足している保証:
- {missing behavior}

推奨対応:
- {recommended test or assertion improvement}
```

## 注意点

- survived mutation を見つけても、直ちに「テストが悪い」と断定しない。
- 仕様上重要でない survived mutation は、低優先度として扱ってよい。
- 逆に killed でも、たまたま別経路で落ちただけなら高評価しない。
