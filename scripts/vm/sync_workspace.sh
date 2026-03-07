#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

source_dir="${1:-${VM_REPO_ROOT}}"
guest_dir="${2:-${HOTKEY_VM_GUEST_WORKSPACE}}"

vm_require_command tart
vm_require_command rsync
vm_wait_for_ssh

vm_ssh /bin/zsh -lc "mkdir -p '${guest_dir}' '${HOTKEY_VM_GUEST_ARTIFACTS_DIR}' '${HOTKEY_VM_GUEST_LOG_DIR}'"

delete_args=()
if [[ "${HOTKEY_VM_SYNC_DELETE}" == "1" ]]; then
    delete_args=(--delete)
fi

exclude_args=(
    --exclude .git/
    --exclude .build/
    --exclude .swiftpm/
    --exclude .tmp/
    --exclude DerivedData/
    --exclude .DS_Store
)

vm_log "Syncing ${source_dir} -> $(vm_guest_target):${guest_dir}"
rsync -az "${delete_args[@]}" "${exclude_args[@]}" \
    -e "$(vm_rsync_ssh_command)" \
    "${source_dir%/}/" \
    "$(vm_guest_target):${guest_dir%/}/"

vm_log "Workspace sync completed"
