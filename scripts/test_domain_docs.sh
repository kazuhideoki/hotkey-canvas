#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)
DEVELOPER_ROOT=$(xcode-select -p)
TOOLCHAIN_HOST_DIR="$DEVELOPER_ROOT/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host"
BUILD_DIR="$REPO_ROOT/.tmp/domain-docs-tests"
BINARY_PATH="$BUILD_DIR/domain-docs"
PRODUCTION_EXPECTED_JSON="$REPO_ROOT/docs/specs/generated/domain-model-relations.json"
PRODUCTION_EXPECTED_MARKDOWN="$REPO_ROOT/docs/specs/generated/domain-model-relations.md"
PRODUCTION_ACTUAL_JSON="$BUILD_DIR/production.json"
PRODUCTION_ACTUAL_MARKDOWN="$BUILD_DIR/production.md"

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

run_positive_fixture() {
  local fixture_name="$1"
  local title="$2"
  local fixture_root="$REPO_ROOT/tools/domain-docs/fixtures/$fixture_name"
  local actual_json="$BUILD_DIR/$fixture_name.actual.json"
  local actual_markdown="$BUILD_DIR/$fixture_name.actual.md"
  local expected_json="$fixture_root/expected/graph.json"
  local expected_markdown="$fixture_root/expected/graph.md"

  "$BINARY_PATH" \
    --repo-root "$fixture_root" \
    --include-dir "$fixture_root/Sources/Domain/Model" \
    --json-output "$actual_json" \
    --markdown-output "$actual_markdown" \
    --title "$title"

  diff -u "$expected_json" "$actual_json"
  diff -u "$expected_markdown" "$actual_markdown"
}

run_negative_fixture() {
  local fixture_name="$1"
  local title="$2"
  local fixture_root="$REPO_ROOT/tools/domain-docs/fixtures/$fixture_name"
  local stderr_path="$BUILD_DIR/$fixture_name.stderr"
  local actual_json="$BUILD_DIR/$fixture_name.actual.json"
  local actual_markdown="$BUILD_DIR/$fixture_name.actual.md"
  local expected_error="$fixture_root/expected/error.txt"

  rm -f "$stderr_path" "$actual_json" "$actual_markdown"

  if "$BINARY_PATH" \
    --repo-root "$fixture_root" \
    --include-dir "$fixture_root/Sources/Domain/Model" \
    --json-output "$actual_json" \
    --markdown-output "$actual_markdown" \
    --title "$title" \
    2>"$stderr_path"; then
    echo "Expected fixture '$fixture_name' to fail, but it succeeded." >&2
    exit 1
  fi

  diff -u "$expected_error" "$stderr_path"
}

run_positive_fixture "basic" "Fixture Domain Model Relations"
run_positive_fixture "projection-bridge" "Projection Bridge Domain Model Relations"

run_negative_fixture "invalid-identifier-target" "Invalid Identifier Target"
run_negative_fixture "inferred-property" "Inferred Property"

MISSING_INCLUDE_STDERR="$BUILD_DIR/missing-include.stderr"
rm -f "$MISSING_INCLUDE_STDERR"
if "$BINARY_PATH" \
  --repo-root "$REPO_ROOT" \
  --include-dir "$REPO_ROOT/tools/domain-docs/fixtures/missing-directory" \
  --json-output "$BUILD_DIR/missing-include.json" \
  --markdown-output "$BUILD_DIR/missing-include.md" \
  --title "Missing Include Directory" \
  2>"$MISSING_INCLUDE_STDERR"; then
  echo "Expected missing include directory check to fail, but it succeeded." >&2
  exit 1
fi

diff -u \
  "$REPO_ROOT/tools/domain-docs/fixtures/missing-include.expected-error.txt" \
  "$MISSING_INCLUDE_STDERR"

echo "Domain docs fixture tests passed."

"$BINARY_PATH" \
  --repo-root "$REPO_ROOT" \
  --include-dir "$REPO_ROOT/Sources/Domain/Model" \
  --json-output "$PRODUCTION_ACTUAL_JSON" \
  --markdown-output "$PRODUCTION_ACTUAL_MARKDOWN" \
  --title "HotkeyCanvas ドメインモデル関係図"

diff -u "$PRODUCTION_EXPECTED_JSON" "$PRODUCTION_ACTUAL_JSON"
diff -u "$PRODUCTION_EXPECTED_MARKDOWN" "$PRODUCTION_ACTUAL_MARKDOWN"

echo "Domain docs production freshness check passed."
