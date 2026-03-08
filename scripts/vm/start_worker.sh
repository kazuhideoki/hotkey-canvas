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
vm_validate_display_mode

pid_file="${HOTKEY_VM_LOCAL_HOST_LOG_DIR}/tart-run.pid"
log_file="${HOTKEY_VM_LOCAL_HOST_LOG_DIR}/tart-run.log"

if [[ -f "${pid_file}" ]] && kill -0 "$(cat "${pid_file}")" 2>/dev/null; then
    vm_log "VM ${HOTKEY_VM_NAME} already has a running tart process"
    vm_wait_for_guest
    vm_log "VM IP: $(vm_tart_ip)"
    exit 0
fi

run_args=()
case "${HOTKEY_VM_DISPLAY_MODE}" in
    no-graphics)
        run_args+=(--no-graphics)
        ;;
    vnc)
        run_args+=(--vnc)
        ;;
    vnc-experimental)
        run_args+=(--vnc-experimental)
        ;;
    gui)
        ;;
esac

share_spec="$(vm_build_dir_share_spec)"
if [[ -n "${share_spec}" ]]; then
    run_args+=(--dir "${share_spec}")
fi

if [[ -n "${HOTKEY_VM_TART_RUN_EXTRA_ARGS}" ]]; then
    extra_args=(${HOTKEY_VM_TART_RUN_EXTRA_ARGS})
    run_args+=("${extra_args[@]}")
fi

vm_log "Starting ${HOTKEY_VM_NAME}"
nohup tart run "${run_args[@]}" "${HOTKEY_VM_NAME}" >"${log_file}" 2>&1 &
echo "$!" > "${pid_file}"

vm_wait_for_guest
vm_log "VM IP: $(vm_tart_ip)"
vm_log "Display mode: ${HOTKEY_VM_DISPLAY_MODE}"
