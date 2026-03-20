# Domain Docs Tool Tests

このディレクトリは `tools/DomainDocs` のテストケースを置く場所であり、実際のプロダクションドメイン定義ではない。

- `Sources/Domain/Model`: 抽出器と renderer を検証するための最小入力
- `expected`: その入力から生成されるべき期待結果

`Sources/Domain/Model` の変更追従は `docs/specs/generated/` の freshness check が担う。ここを変更するのは、`tools/DomainDocs` 配下のツール実装や、そこから生成される `domain-docs` バイナリの仕様・テスト観点を追加または変更するときだけにする。
