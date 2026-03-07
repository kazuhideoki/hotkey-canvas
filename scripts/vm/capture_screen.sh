#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/capture_screen.sh [output-relative-path]

Captures the guest display and saves the PNG into the shared repo path.
Default output: .tmp/vm-artifacts/guest-screen.png
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

relative_output_path="${1:-.tmp/vm-artifacts/guest-screen.png}"
shared_root="$(vm_shared_repo_guest_root)"
guest_output_path="${shared_root}/${relative_output_path}"

vm_require_command tart

remote_script="$(cat <<EOF
set -euo pipefail
mkdir -p "$(dirname "${guest_output_path}")"
screencapture -x '${guest_output_path}'
ls -lh '${guest_output_path}'
EOF
)"

vm_log "Capturing guest display -> ${relative_output_path}"
tart exec "${HOTKEY_VM_NAME}" /bin/zsh -lc "${remote_script}"
