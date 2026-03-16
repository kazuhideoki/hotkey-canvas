#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

vm_require_command tart
vm_wait_for_guest

remote_reset_script="$(cat <<EOF
set -euo pipefail
pid_file='${HOTKEY_VM_GUEST_LOG_DIR}/hotkey-canvas.pid'
if [[ -f "\${pid_file}" ]] && kill -0 "\$(cat "\${pid_file}")" 2>/dev/null; then
    kill "\$(cat "\${pid_file}")" 2>/dev/null || true
    sleep 1
fi
pkill -x HotkeyCanvasApp 2>/dev/null || true
pkill -f 'swift run HotkeyCanvasApp' 2>/dev/null || true
rm -f "\${pid_file}"
EOF
)"

vm_log "Restarting HotkeyCanvas debug app"
vm_tart_exec /bin/zsh -lc "${remote_reset_script}"
"${script_dir}/start_hotkey_canvas_debug.sh"
