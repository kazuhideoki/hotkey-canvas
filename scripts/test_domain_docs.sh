#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DEVELOPER_ROOT=$(xcode-select -p)
TOOLCHAIN_HOST_DIR="$DEVELOPER_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host"
BUILD_DIR="$REPO_ROOT/.tmp/domain-docs-tests"
BINARY_PATH="$BUILD_DIR/domain-docs"
FIXTURE_ROOT="$REPO_ROOT/tools/domain-docs/fixtures/basic"
ACTUAL_JSON="$BUILD_DIR/actual.json"
ACTUAL_MARKDOWN="$BUILD_DIR/actual.md"
EXPECTED_JSON="$FIXTURE_ROOT/expected/graph.json"
EXPECTED_MARKDOWN="$FIXTURE_ROOT/expected/graph.md"

mkdir -p "$BUILD_DIR"

swiftc \
  -I "$TOOLCHAIN_HOST_DIR" \
  -L "$TOOLCHAIN_HOST_DIR" \
  -Xlinker -rpath \
  -Xlinker "$TOOLCHAIN_HOST_DIR" \
  -lSwiftParser \
  -lSwiftSyntax \
  "$REPO_ROOT"/tools/domain-docs/*.swift \
  -o "$BINARY_PATH"

"$BINARY_PATH" \
  --repo-root "$FIXTURE_ROOT" \
  --include-dir "$FIXTURE_ROOT/Sources/Domain/Model" \
  --json-output "$ACTUAL_JSON" \
  --markdown-output "$ACTUAL_MARKDOWN" \
  --title "Fixture Domain Model Relations"

diff -u "$EXPECTED_JSON" "$ACTUAL_JSON"
diff -u "$EXPECTED_MARKDOWN" "$ACTUAL_MARKDOWN"

echo "Domain docs fixture tests passed."

