#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0

cd "$repo_root"

if ! swift format --in-place --recursive --parallel --configuration .swift-format Sources Tests; then
    status=1
fi

if ! swift format lint --recursive --configuration .swift-format Sources Tests; then
    status=1
fi

if ! swift package plugin --allow-writing-to-package-directory swiftlint -- --strict; then
    status=1
fi

if ! "$repo_root/scripts/bootstrap_periphery.sh"; then
    status=1
fi

if ! "$repo_root/.tools/periphery/3.6.0/periphery" scan --retain-codable-properties; then
    status=1
fi

exit "$status"
