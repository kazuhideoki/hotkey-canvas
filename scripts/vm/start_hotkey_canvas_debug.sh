#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

vm_require_command tart
vm_wait_for_guest

remote_script="$(cat <<EOF
set -euo pipefail
workspace_dir='$(vm_guest_workspace_dir)'
log_dir='${HOTKEY_VM_GUEST_LOG_DIR}'
mkdir -p "\${log_dir}"
if [[ ! -f "\${workspace_dir}/Package.swift" ]]; then
    echo "error: Package.swift was not found in \${workspace_dir}. Configure HOTKEY_VM_GUEST_WORKSPACE or mount the repo with --dir." >&2
    exit 1
fi
pid_file="\${log_dir}/hotkey-canvas.pid"
log_file="\${log_dir}/hotkey-canvas.log"
if [[ -f "\${pid_file}" ]] && kill -0 "\$(cat "\${pid_file}")" 2>/dev/null; then
    exit 0
fi
cd "\${workspace_dir}"
nohup swift run HotkeyCanvasApp -- --enable-debug-state-api --debug-state-port=${HOTKEY_VM_DEBUG_STATE_PORT} --debug-state-token='${HOTKEY_VM_DEBUG_STATE_TOKEN}' >"\${log_file}" 2>&1 &
echo \$! > "\${pid_file}"
EOF
)"

vm_log "Starting HotkeyCanvas with debug-state API"
vm_tart_exec /bin/zsh -lc "${remote_script}"
vm_wait_for_http "$(vm_debug_state_url "/debug/v1/health")" "Authorization: Bearer ${HOTKEY_VM_DEBUG_STATE_TOKEN}"

vm_log "HotkeyCanvas debug-state API is reachable"
