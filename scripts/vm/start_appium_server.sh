#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

vm_require_command tart
vm_wait_for_ssh

base_path="$(vm_normalize_http_base_path "${HOTKEY_VM_APPIUM_BASE_PATH}")"
remote_script="$(cat <<EOF
set -euo pipefail
log_dir='${HOTKEY_VM_GUEST_LOG_DIR}'
mkdir -p "\${log_dir}"
pid_file="\${log_dir}/appium.pid"
log_file="\${log_dir}/appium.log"
command -v appium >/dev/null 2>&1 || {
    echo "error: appium is not installed in the guest VM." >&2
    exit 1
}
if ! appium driver list --installed | grep -q 'mac2'; then
    echo "error: appium-mac2-driver is not installed in the guest VM." >&2
    exit 1
fi
if [[ -f "\${pid_file}" ]] && kill -0 "\$(cat "\${pid_file}")" 2>/dev/null; then
    exit 0
fi
nohup appium server --address 127.0.0.1 --port ${HOTKEY_VM_APPIUM_PORT} --base-path '${base_path}' >"\${log_file}" 2>&1 &
echo \$! > "\${pid_file}"
EOF
)"

vm_log "Starting Appium server in guest"
vm_ssh /bin/zsh -lc "${remote_script}"
vm_wait_for_http "$(vm_appium_status_url)"

vm_log "Appium status endpoint is reachable"
