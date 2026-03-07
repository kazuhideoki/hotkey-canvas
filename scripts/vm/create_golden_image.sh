#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

HOTKEY_VM_BASE_IMAGE_SOURCE="${HOTKEY_VM_BASE_IMAGE_SOURCE:-ghcr.io/cirruslabs/macos-sequoia-base:latest}"

usage() {
    cat <<EOF
Usage: scripts/vm/create_golden_image.sh

Environment:
  HOTKEY_VM_BASE_IMAGE_SOURCE   Remote Tart image to clone from.
  HOTKEY_VM_GOLDEN_IMAGE        Local golden image name to create.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

vm_require_command tart

if tart list | awk '{print $2}' | grep -Fxq "${HOTKEY_VM_GOLDEN_IMAGE}"; then
    vm_log "Golden image already exists: ${HOTKEY_VM_GOLDEN_IMAGE}"
    exit 0
fi

vm_log "Cloning ${HOTKEY_VM_BASE_IMAGE_SOURCE} -> ${HOTKEY_VM_GOLDEN_IMAGE}"
tart clone "${HOTKEY_VM_BASE_IMAGE_SOURCE}" "${HOTKEY_VM_GOLDEN_IMAGE}"
vm_log "Golden image created: ${HOTKEY_VM_GOLDEN_IMAGE}"
