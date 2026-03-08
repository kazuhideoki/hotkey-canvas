#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

endpoint="${1:-/debug/v1/health}"
output_path="${2:-}"

vm_require_command tart
vm_wait_for_guest

if [[ -n "${output_path}" ]]; then
    mkdir -p "$(dirname "${output_path}")"
    vm_tart_exec /usr/bin/curl -fsS \
        -H "Authorization: Bearer ${HOTKEY_VM_DEBUG_STATE_TOKEN}" \
        "$(vm_debug_state_url "${endpoint}")" > "${output_path}"
    vm_log "Saved ${endpoint} -> ${output_path}"
    exit 0
fi

vm_tart_exec /usr/bin/curl -fsS \
    -H "Authorization: Bearer ${HOTKEY_VM_DEBUG_STATE_TOKEN}" \
    "$(vm_debug_state_url "${endpoint}")"
