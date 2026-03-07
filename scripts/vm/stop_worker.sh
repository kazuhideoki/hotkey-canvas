#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

if [[ $# -gt 0 ]]; then
    HOTKEY_VM_NAME="$1"
    vm_refresh_local_paths
fi

vm_require_command tart
vm_ensure_local_dirs

pid_file="${HOTKEY_VM_LOCAL_HOST_LOG_DIR}/tart-run.pid"

vm_log "Stopping ${HOTKEY_VM_NAME}"
tart stop "${HOTKEY_VM_NAME}" >/dev/null 2>&1 || true

if [[ -f "${pid_file}" ]]; then
    if kill -0 "$(cat "${pid_file}")" 2>/dev/null; then
        wait "$(cat "${pid_file}")" 2>/dev/null || true
    fi
    rm -f "${pid_file}"
fi

vm_log "VM stopped: ${HOTKEY_VM_NAME}"
