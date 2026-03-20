#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DEVELOPER_ROOT=$(xcode-select -p)
TOOLCHAIN_HOST_DIR="$DEVELOPER_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host"
BUILD_DIR="$REPO_ROOT/.tmp/domain-docs"
BINARY_PATH="$BUILD_DIR/domain-docs"
JSON_OUTPUT_PATH="$REPO_ROOT/docs/specs/generated/domain-model-relations.json"
MARKDOWN_OUTPUT_PATH="$REPO_ROOT/docs/specs/generated/domain-model-relations.md"

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
  --repo-root "$REPO_ROOT" \
  --include-dir "$REPO_ROOT/Sources/Domain/Model" \
  --json-output "$JSON_OUTPUT_PATH" \
  --markdown-output "$MARKDOWN_OUTPUT_PATH" \
  --title "HotkeyCanvas ドメインモデル関係図"

echo "Wrote $JSON_OUTPUT_PATH"
echo "Wrote $MARKDOWN_OUTPUT_PATH"

