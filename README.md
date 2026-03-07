# hotkey-canvas

HotkeyCanvas is a macOS application for keyboard-first canvas editing.  

## Development Commands

```bash
./scripts/bootstrap_periphery.sh
swift run HotkeyCanvasApp
swift build
swift test
./scripts/lint_and_format.sh
```

`./scripts/lint_and_format.sh` bootstraps a repo-local Periphery binary under `.tools/` and runs unused-code detection from there. The intent is to avoid requiring a global `brew`/`mint` install while keeping the Periphery version consistent across local development and CI. The Periphery invocation retains `Codable` properties to reduce false positives for DTO/JSON mapping code.

`./scripts/lint_and_format.sh` is intentionally a fix-and-verify script, not a check-only script. It applies auto-fixable formatting first, then fails only on issues that still require manual changes. If CI uses this script, it should additionally verify that no file changes remain after execution.

The first bootstrap downloads Periphery from GitHub Releases, so `curl`, `unzip`, and network access are required once even though no global package manager install is needed.

## Test Conventions

- Unit/contract tests: `*Tests.swift`
- UI-like regression scenarios on `swift test`: `*UITests.swift`

## Roadmap

- Mind map-style node management
- Miro-style diagram creation
