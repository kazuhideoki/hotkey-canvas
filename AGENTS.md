# Repository Guidelines

## Architecture Reference

`docs/architecture.md` is the single source of truth for layer responsibilities, dependency direction, directory placement, naming conventions, and UI display flow rules.

## Project Structure & Module Organization

Follow `docs/architecture.md` for layer boundaries, dependency rules, and placement decisions.

## Build, Test, and Development Commands

Canonical commands:

- `cat docs/architecture.md`: review constraints before coding.
- `swift build`
- `swift test`
- `git log --oneline`: inspect prior commit style.
- `find . -maxdepth 3 -type f`: verify expected scaffold files.

## Coding Style & Naming Conventions

- Language target: Swift.
- Use 4-space indentation and keep one primary type per file.
- Keep domain logic pure in `Domain/`; keep framework/API details in adapters.
- Naming rules are defined in `docs/architecture.md`.
- Lint/type safety rules:
  - `Any` is prohibited (SwiftLint `custom_rules.no_any_type` as `error`).
  - Prefer concrete types, generics, or `any Protocol`.
  - Run lint with `./scripts/lint.sh` (Swift Package Plugin based; no global SwiftLint required).

## Testing Guidelines

- Test placement and naming rules are defined in `docs/architecture.md`.
- Prioritize domain invariants and use-case behavior first, then adapter mapping and integration flows.
- Add regression tests with each bug fix.

## Commit & Pull Request Guidelines

Current history uses short, imperative summaries (for example, `initial archi plan`, `first commit`). Prefer clearer variants like:

- `Add domain command model scaffold`
- `Define apply use-case port contracts`

For pull requests, include:

- Scope summary and affected layers.
- Linked issue/task.
- Architecture impact note (especially dependency direction).
- Test evidence (what was run, or why tests are pending).
