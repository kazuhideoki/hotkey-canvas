#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/send_vnc_keys.sh <stroke>...

Send key strokes to the guest over VNC without opening a host-side viewer.

Stroke syntax:
  - single key: d
  - modified key: shift+enter
  - mouse move: move:500:350
  - mouse click: click:1
  - pause: pause:0.5

The key token is passed to vncdotool after replacing '+' with '-'.
EOF
}

if [[ $# -eq 0 || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

vm_require_command tart
vm_wait_for_guest

vncdotool_bin="$(vm_resolve_vncdotool)"
vnc_host="${HOTKEY_VM_VNC_HOST:-$(vm_tart_ip)}"
vnc_server="${vnc_host}::${HOTKEY_VM_VNC_PORT}"
script_path="${HOTKEY_VM_LOCAL_HOST_LOG_DIR}/send-vnc-keys.txt"

mkdir -p "$(dirname "${script_path}")"
{
    for stroke in "$@"; do
        if [[ "${stroke}" == pause:* ]]; then
            printf 'pause %s\n' "${stroke#pause:}"
        elif [[ "${stroke}" == move:*:* ]]; then
            move_x="${stroke#move:}"
            move_x="${move_x%%:*}"
            move_y="${stroke##*:}"
            printf 'move %s %s\n' "${move_x}" "${move_y}"
        elif [[ "${stroke}" == click:* ]]; then
            printf 'click %s\n' "${stroke#click:}"
        else
            printf 'key %s\n' "${stroke//+/-}"
        fi
    done
} > "${script_path}"

vm_log "Sending VNC key strokes to ${HOTKEY_VM_NAME}: $*"
"${vncdotool_bin}" \
    -u "${HOTKEY_VM_VNC_USERNAME}" \
    -p "${HOTKEY_VM_VNC_PASSWORD}" \
    -s "${vnc_server}" \
    "${script_path}"
