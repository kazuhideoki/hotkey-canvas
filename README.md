# hotkey-canvas

## Commands

```bash
# 型チェック（コンパイル）
swift build

# テスト
swift test

# Lint
./scripts/lint.sh
```

Lint / Type Safety の具体ルールは `AGENTS.md` を参照。

## Dependencies

- `Package.swift` で `SimplyDanny/SwiftLintPlugins` を依存に追加済み。
- バージョンは `Package.resolved` で固定される。
- 初回実行時のみ SwiftLint バイナリアーティファクトの取得が発生する。
