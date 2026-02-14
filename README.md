# hotkey-canvas

<<<<<<< HEAD
## Lint

Swift 向けリンターとして `SwiftLint` を Swift Package Plugin 経由で導入済みです。

```bash
./scripts/lint.sh
```

設定は `.swiftlint.yml` にあります。
=======
## Type Safety Rules

- `Any` is prohibited (`.swiftlint.yml` -> `no_any_type` as `error`).
- Prefer concrete types, generics, or `any Protocol`.

## Lint

```bash
brew install swiftlint
swiftlint lint
```
>>>>>>> main
