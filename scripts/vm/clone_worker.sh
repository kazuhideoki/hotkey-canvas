#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

if [[ $# -gt 0 ]]; then
    HOTKEY_VM_NAME="$1"
    vm_refresh_local_paths
fi

if [[ $# -gt 1 ]]; then
    HOTKEY_VM_GOLDEN_IMAGE="$2"
fi

vm_require_command tart
vm_ensure_local_dirs

vm_log "Cloning ${HOTKEY_VM_GOLDEN_IMAGE} -> ${HOTKEY_VM_NAME}"
tart clone "${HOTKEY_VM_GOLDEN_IMAGE}" "${HOTKEY_VM_NAME}"
vm_apply_display_resolution_if_configured

vm_log "Worker VM is ready: ${HOTKEY_VM_NAME}"
