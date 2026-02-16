#!/usr/bin/env bash
set -euo pipefail

swift format --in-place --recursive --parallel --configuration .swift-format Sources Tests
swift format lint --recursive --configuration .swift-format Sources Tests
swift package plugin --allow-writing-to-package-directory swiftlint -- --strict
