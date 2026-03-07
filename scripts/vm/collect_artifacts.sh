#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

vm_require_command tart
vm_require_command rsync
vm_wait_for_ssh
vm_ensure_local_dirs

logs_dir="${HOTKEY_VM_LOCAL_ARTIFACTS_DIR}/logs"
artifacts_dir="${HOTKEY_VM_LOCAL_ARTIFACTS_DIR}/artifacts"
mkdir -p "${logs_dir}" "${artifacts_dir}"

vm_ssh /bin/zsh -lc "mkdir -p '${HOTKEY_VM_GUEST_LOG_DIR}' '${HOTKEY_VM_GUEST_ARTIFACTS_DIR}'"

vm_log "Collecting guest logs"
rsync -az -e "$(vm_rsync_ssh_command)" \
    "$(vm_guest_target):${HOTKEY_VM_GUEST_LOG_DIR%/}/" \
    "${logs_dir}/"

vm_log "Collecting guest artifacts"
rsync -az -e "$(vm_rsync_ssh_command)" \
    "$(vm_guest_target):${HOTKEY_VM_GUEST_ARTIFACTS_DIR%/}/" \
    "${artifacts_dir}/"

vm_log "Artifacts saved under ${HOTKEY_VM_LOCAL_ARTIFACTS_DIR}"
