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
    tart_run_pid="$(cat "${pid_file}")"
    if kill -0 "${tart_run_pid}" 2>/dev/null; then
        deadline=$((SECONDS + 10))
        while kill -0 "${tart_run_pid}" 2>/dev/null; do
            if ((SECONDS >= deadline)); then
                vm_error "tart run process did not exit after stop; sending TERM to ${tart_run_pid}"
                kill "${tart_run_pid}" 2>/dev/null || true
                sleep 1
                if kill -0 "${tart_run_pid}" 2>/dev/null; then
                    vm_error "tart run process still alive; sending KILL to ${tart_run_pid}"
                    kill -9 "${tart_run_pid}" 2>/dev/null || true
                fi
                break
            fi
            sleep 1
        done
    fi
    rm -f "${pid_file}"
fi

vm_log "VM stopped: ${HOTKEY_VM_NAME}"
