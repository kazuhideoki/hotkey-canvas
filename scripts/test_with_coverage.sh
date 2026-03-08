#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
threshold_config_path="$repo_root/scripts/test_with_coverage_threshold.json"
test_filter=""
focus_sources=()
changed_since_ref=""
clean_requested=0
filter_requested=0
focus_requested=0

usage() {
    cat <<'EOF'
Usage:
  ./scripts/test_with_coverage.sh [options]

Options:
  --clean                   Run `swift package clean` before testing.
  --filter <pattern>        Pass through to `swift test --filter`.
                            Use identifiers shown by `swift test list`.
  --focus-source <path>     Report focused coverage for matching source path.
                            Repeatable. Match is done against `Sources/...`.
  --changed-since <git-ref> Focus coverage on source files changed since <git-ref>.
                            When focus targets are present, coverage thresholds
                            are evaluated per focused source file.
  --help                    Show this help.

Examples:
  ./scripts/test_with_coverage.sh
  ./scripts/test_with_coverage.sh --clean
  ./scripts/test_with_coverage.sh --filter DomainTests.test_validation_invalidOperations_throwExpectedErrors
  ./scripts/test_with_coverage.sh --filter DomainTests.test_validation_invalidOperations_throwExpectedErrors --focus-source Sources/Domain/Service/CanvasGraphCRUDService.swift
  ./scripts/test_with_coverage.sh --changed-since origin/main
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clean)
            clean_requested=1
            shift
            ;;
        --filter)
            if [[ $# -lt 2 ]]; then
                echo "--filter requires a value" >&2
                exit 1
            fi
            filter_requested=1
            test_filter="$2"
            shift 2
            ;;
        --focus-source)
            if [[ $# -lt 2 ]]; then
                echo "--focus-source requires a value" >&2
                exit 1
            fi
            focus_requested=1
            focus_sources+=("$2")
            shift 2
            ;;
        --changed-since)
            if [[ $# -lt 2 ]]; then
                echo "--changed-since requires a git ref" >&2
                exit 1
            fi
            focus_requested=1
            changed_since_ref="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

cd "$repo_root"

if [[ -n "$changed_since_ref" ]]; then
    if ! git rev-parse --verify --quiet "${changed_since_ref}^{commit}" >/dev/null; then
        echo "error: --changed-since ref '${changed_since_ref}' was not found locally." >&2
        exit 1
    fi

    while IFS= read -r changed_path; do
        [[ -n "$changed_path" ]] || continue
        focus_sources+=("$changed_path")
    done < <(git diff --name-only "${changed_since_ref}...HEAD" -- Sources)

    while IFS= read -r changed_path; do
        [[ -n "$changed_path" ]] || continue
        focus_sources+=("$changed_path")
    done < <(git diff --name-only --cached -- Sources)

    while IFS= read -r changed_path; do
        [[ -n "$changed_path" ]] || continue
        focus_sources+=("$changed_path")
    done < <(git diff --name-only -- Sources)

    while IFS= read -r changed_path; do
        [[ -n "$changed_path" ]] || continue
        focus_sources+=("$changed_path")
    done < <(git ls-files --others --exclude-standard -- Sources)
fi

if [[ "$clean_requested" -eq 1 ]]; then
    swift package clean
fi

json_path="$(swift test --enable-code-coverage --show-codecov-path | tail -n 1)"

if [[ -z "${json_path:-}" ]]; then
    echo "Coverage JSON path was not resolved." >&2
    exit 1
fi

test_log="$(mktemp)"
trap 'rm -f "$test_log"' EXIT

test_cmd=(swift test --enable-code-coverage)
if [[ "$filter_requested" -eq 1 ]]; then
    test_cmd+=(--filter "$test_filter")
fi

if ! "${test_cmd[@]}" 2>&1 | tee "$test_log"; then
    exit 1
fi

if [[ "$filter_requested" -eq 1 ]] && grep -q "No matching test cases were run" "$test_log"; then
    echo "error: --filter did not match any tests. Use 'swift test list' to confirm the identifier." >&2
    exit 1
fi

if [[ ! -f "$json_path" ]]; then
    echo "Coverage JSON was not generated." >&2
    exit 1
fi

if [[ ! -f "$threshold_config_path" ]]; then
    echo "Coverage threshold config was not found: $threshold_config_path" >&2
    exit 1
fi

python3 - "$json_path" "$threshold_config_path" "$focus_requested" "${focus_sources[@]-}" <<'PY'
import json
import sys
from pathlib import Path
from collections import defaultdict

json_path = Path(sys.argv[1])
threshold_config_path = Path(sys.argv[2])
focus_requested = sys.argv[3] == "1"
focus_inputs = [value for value in sys.argv[4:] if value]
payload = json.loads(json_path.read_text())
threshold_config = json.loads(threshold_config_path.read_text())

source_totals = {
    "covered": 0,
    "count": 0,
}
layer_totals = defaultdict(lambda: {"covered": 0, "count": 0})
focus_totals = {
    "covered": 0,
    "count": 0,
}
focus_files = []

threshold_rules = [
    (
        item["path_prefix"],
        float(item["minimum_line_coverage"]),
    )
    for item in threshold_config.get("focus_file_thresholds", [])
]

layer_thresholds = {
    layer_name: float(minimum_line_coverage)
    for layer_name, minimum_line_coverage in threshold_config.get("layer_thresholds", {}).items()
}

def normalize_focus_path(raw: str) -> str:
    value = raw.strip()
    marker = "Sources/"
    if marker in value:
        return value[value.index(marker):]
    return value.lstrip("./")

normalized_focus_inputs = [normalize_focus_path(value) for value in focus_inputs]
normalized_focus_inputs = list(dict.fromkeys(normalized_focus_inputs))

def percent(covered: int, count: int) -> float:
    return (covered / count * 100) if count else 0.0

def matching_threshold(path: str):
    for prefix, threshold in threshold_rules:
        if path.startswith(prefix):
            return prefix, threshold
    return None

for datum in payload.get("data", []):
    for file_payload in datum.get("files", []):
        filename = file_payload.get("filename", "")
        marker = "/Sources/"
        if marker not in filename:
            continue

        relative_path = filename.split(marker, 1)[1]
        layer_name = relative_path.split("/", 1)[0]
        lines = file_payload.get("summary", {}).get("lines", {})
        covered = int(lines.get("covered", 0))
        count = int(lines.get("count", 0))

        source_totals["covered"] += covered
        source_totals["count"] += count
        layer_totals[layer_name]["covered"] += covered
        layer_totals[layer_name]["count"] += count

        if normalized_focus_inputs and any(token in f"Sources/{relative_path}" for token in normalized_focus_inputs):
            focus_totals["covered"] += covered
            focus_totals["count"] += count
            focus_files.append((f"Sources/{relative_path}", covered, count))

rate = percent(source_totals["covered"], source_totals["count"])

print(f"COVERAGE_JSON={json_path}")
print(f"COVERAGE_THRESHOLD_CONFIG={threshold_config_path}")
print(f"TOTAL_REPORTED_SOURCE_LINE_COVERAGE={rate:.2f}% ({source_totals['covered']}/{source_totals['count']})")

for name in sorted(layer_totals):
    covered = layer_totals[name]["covered"]
    count = layer_totals[name]["count"]
    layer_rate = percent(covered, count)
    print(f"LAYER {name}: {layer_rate:.2f}% ({covered}/{count})")

coverage_failures = []
coverage_checks = []

if focus_requested:
    if normalized_focus_inputs:
        print("FOCUS_MATCHERS=" + ", ".join(normalized_focus_inputs))
    else:
        print("FOCUS_MATCHERS=NO_MATCH")

    if focus_files:
        focus_rate = percent(focus_totals["covered"], focus_totals["count"])
        print(f"FOCUSED_SOURCE_LINE_COVERAGE={focus_rate:.2f}% ({focus_totals['covered']}/{focus_totals['count']})")
        for path, covered, count in sorted(focus_files):
            file_rate = percent(covered, count)
            print(f"FOCUS {path}: {file_rate:.2f}% ({covered}/{count})")
            matched_rule = matching_threshold(path)
            if matched_rule is None:
                continue
            prefix, threshold = matched_rule
            passed = file_rate >= threshold
            status = "PASS" if passed else "FAIL"
            message = (
                f"CHECK {status} {path}: {file_rate:.2f}% >= {threshold:.2f}% "
                f"(rule: {prefix})"
            )
            coverage_checks.append(message)
            if not passed:
                coverage_failures.append(message)
    else:
        print("FOCUSED_SOURCE_LINE_COVERAGE=NO_MATCH")
else:
    for name in sorted(layer_totals):
        threshold = layer_thresholds.get(name)
        if threshold is None:
            continue
        covered = layer_totals[name]["covered"]
        count = layer_totals[name]["count"]
        layer_rate = percent(covered, count)
        passed = layer_rate >= threshold
        status = "PASS" if passed else "FAIL"
        message = f"CHECK {status} LAYER {name}: {layer_rate:.2f}% >= {threshold:.2f}%"
        coverage_checks.append(message)
        if not passed:
            coverage_failures.append(message)

if coverage_checks:
    for message in coverage_checks:
        print(message)
else:
    print("CHECK PASS: no threshold rules matched")

if coverage_failures:
    print("COVERAGE_CHECK=FAIL")
    sys.exit(1)

print("COVERAGE_CHECK=PASS")
PY
