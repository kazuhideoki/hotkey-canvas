#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/capture_screen.sh [output-relative-path]

Captures the guest VNC display from the host and saves the PNG under the repo.
Default output: .tmp/vm-artifacts/guest-screen.png
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

relative_output_path="${1:-.tmp/vm-artifacts/guest-screen.png}"
host_output_path="${VM_REPO_ROOT}/${relative_output_path}"

resolve_vncdotool() {
    vm_resolve_vncdotool
}

vm_require_command tart
vm_wait_for_guest
mkdir -p "$(dirname "${host_output_path}")"

vnc_host="${HOTKEY_VM_VNC_HOST:-$(vm_tart_ip)}"
vnc_server="${vnc_host}::${HOTKEY_VM_VNC_PORT}"
vncdotool_bin="$(resolve_vncdotool)"

vm_log "Capturing guest display via VNC -> ${relative_output_path}"
"${vncdotool_bin}" \
    -u "${HOTKEY_VM_VNC_USERNAME}" \
    -p "${HOTKEY_VM_VNC_PASSWORD}" \
    -s "${vnc_server}" \
    capture "${host_output_path}"

ls -lh "${host_output_path}"
