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

run_positive_test_case() {
  local test_case_name="$1"
  local title="$2"
  local test_case_root="$REPO_ROOT/tools/domain-docs/tests/$test_case_name"
  local actual_json="$BUILD_DIR/$test_case_name.actual.json"
  local actual_markdown="$BUILD_DIR/$test_case_name.actual.md"
  local expected_json="$test_case_root/expected/graph.json"
  local expected_markdown="$test_case_root/expected/graph.md"

  "$BINARY_PATH" \
    --repo-root "$test_case_root" \
    --include-dir "$test_case_root/Sources/Domain/Model" \
    --json-output "$actual_json" \
    --markdown-output "$actual_markdown" \
    --title "$title"

  diff -u "$expected_json" "$actual_json"
  diff -u "$expected_markdown" "$actual_markdown"
}

run_negative_test_case() {
  local test_case_name="$1"
  local title="$2"
  local test_case_root="$REPO_ROOT/tools/domain-docs/tests/$test_case_name"
  local stderr_path="$BUILD_DIR/$test_case_name.stderr"
  local actual_json="$BUILD_DIR/$test_case_name.actual.json"
  local actual_markdown="$BUILD_DIR/$test_case_name.actual.md"
  local expected_error="$test_case_root/expected/error.txt"

  rm -f "$stderr_path" "$actual_json" "$actual_markdown"

  if "$BINARY_PATH" \
    --repo-root "$test_case_root" \
    --include-dir "$test_case_root/Sources/Domain/Model" \
    --json-output "$actual_json" \
    --markdown-output "$actual_markdown" \
    --title "$title" \
    2>"$stderr_path"; then
    echo "Expected test case '$test_case_name' to fail, but it succeeded." >&2
    exit 1
  fi

  diff -u "$expected_error" "$stderr_path"
}

run_positive_test_case "basic" "Fixture Domain Model Relations"
run_positive_test_case "projection-bridge" "Projection Bridge Domain Model Relations"

run_negative_test_case "invalid-identifier-target" "Invalid Identifier Target"
run_negative_test_case "inferred-property" "Inferred Property"

MISSING_INCLUDE_STDERR="$BUILD_DIR/missing-include.stderr"
MISSING_INCLUDE_EXPECTED_FRAGMENT=$(cat "$REPO_ROOT/tools/domain-docs/tests/missing-include.error.txt")
rm -f "$MISSING_INCLUDE_STDERR"
if "$BINARY_PATH" \
  --repo-root "$REPO_ROOT" \
  --include-dir "$REPO_ROOT/tools/domain-docs/tests/missing-directory" \
  --json-output "$BUILD_DIR/missing-include.json" \
  --markdown-output "$BUILD_DIR/missing-include.md" \
  --title "Missing Include Directory" \
  2>"$MISSING_INCLUDE_STDERR"; then
  echo "Expected missing include directory check to fail, but it succeeded." >&2
  exit 1
fi

if ! grep -Fq "$MISSING_INCLUDE_EXPECTED_FRAGMENT" "$MISSING_INCLUDE_STDERR"; then
  echo "Missing include directory error did not contain the expected stable fragment." >&2
  cat "$MISSING_INCLUDE_STDERR" >&2
  exit 1
fi

echo "Domain docs tool tests passed."

"$BINARY_PATH" \
  --repo-root "$REPO_ROOT" \
  --include-dir "$REPO_ROOT/Sources/Domain/Model" \
  --json-output "$PRODUCTION_ACTUAL_JSON" \
  --markdown-output "$PRODUCTION_ACTUAL_MARKDOWN" \
  --title "HotkeyCanvas ドメインモデル関係図"

diff -u "$PRODUCTION_EXPECTED_JSON" "$PRODUCTION_ACTUAL_JSON"
diff -u "$PRODUCTION_EXPECTED_MARKDOWN" "$PRODUCTION_ACTUAL_MARKDOWN"

echo "Domain docs production freshness check passed."
