#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/session_up.sh [options]

Bring up a VM work session for exploratory GUI checks.

Options:
  --clone            Clone HOTKEY_VM_GOLDEN_IMAGE into HOTKEY_VM_NAME first.
  --prepare-guest    Run prepare_guest_image.sh after the VM becomes ready.
  --install-appium   Pass --install-appium to prepare_guest_image.sh.
  --check-guest      Run check_guest_setup.sh after setup.
  --start-app        Launch HotkeyCanvas with debug-state API.
  --help             Show this help.
EOF
}

clone_vm=false
prepare_guest=false
install_appium=false
check_guest=false
start_app=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --clone)
            clone_vm=true
            ;;
        --prepare-guest)
            prepare_guest=true
            ;;
        --install-appium)
            install_appium=true
            ;;
        --check-guest)
            check_guest=true
            ;;
        --start-app)
            start_app=true
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            vm_die "unknown argument: $1"
            ;;
    esac
    shift
done

if [[ "${install_appium}" == true && "${prepare_guest}" != true ]]; then
    vm_die "--install-appium requires --prepare-guest"
fi

if [[ "${clone_vm}" == true ]]; then
    vm_log "session_up: clone worker VM"
    "${script_dir}/clone_worker.sh"
fi

vm_log "session_up: start worker VM"
"${script_dir}/start_worker.sh"

if [[ "${prepare_guest}" == true ]]; then
    vm_log "session_up: prepare guest"
    prepare_args=()
    if [[ "${install_appium}" == true ]]; then
        prepare_args+=(--install-appium)
    fi
    "${script_dir}/prepare_guest_image.sh" "${prepare_args[@]}"
fi

if [[ "${check_guest}" == true ]]; then
    vm_log "session_up: check guest prerequisites"
    "${script_dir}/check_guest_setup.sh"
fi

if [[ "${start_app}" == true ]]; then
    vm_log "session_up: start HotkeyCanvas debug app"
    "${script_dir}/start_hotkey_canvas_debug.sh"
fi

vm_log "session_up: ready"
vm_log "next: use tart exec or scripts/vm/send_keys.sh, send_vnc_keys.sh, fetch_debug_state.sh, capture_screen.sh"
