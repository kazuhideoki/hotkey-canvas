# Repository Guidelines

## Project Structure & Module Organization
This repository is currently an architecture scaffold for a macOS app using Clean Architecture boundaries.

- `App/`: app entrypoint and dependency wiring only.
- `Domain/`: core models, commands, services, and domain errors.
- `Application/`: use cases, DTOs, ports, and coordinators.
- `InterfaceAdapters/`: input/output/persistence/agent integration adapters.
- `Infrastructure/`: cross-cutting concerns (logging, diagnostics).
- `Tests/`: split by layer (`DomainTests`, `ApplicationTests`, `InterfaceAdapterTests`, `IntegrationTests`).
- `docs/architecture.md`: source of truth for dependency and layering rules.

Keep dependencies directed inward (for example, adapters can depend on `Application`/`Domain`, but `Domain` must not depend on outer layers).

## Build, Test, and Development Commands
No build system file (`Package.swift`, `.xcodeproj`, `Makefile`) is committed yet. At this stage, use:

- `cat docs/architecture.md`: review architecture constraints before coding.
- `git log --oneline`: inspect prior commit style.
- `find . -maxdepth 3 -type f`: verify expected scaffold files.

When introducing executable code, add and document canonical commands in this file (for example `swift build`, `swift test`, or `xcodebuild ...`).

## Coding Style & Naming Conventions
- Language target: Swift (per architecture doc and directory design).
- Use 4-space indentation and keep one primary type per file.
- Use `UpperCamelCase` for types (`CanvasState`), `lowerCamelCase` for methods/properties, and verb-first names for use cases (`ApplyCanvasCommandsUseCase`).
- Keep domain logic pure in `Domain/`; keep framework/API details in adapters.

## Testing Guidelines
- Mirror production structure under `Tests/` by layer.
- Name test files as `<TypeName>Tests.swift`; name tests as `test_<condition>_<expectedResult>()`.
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
