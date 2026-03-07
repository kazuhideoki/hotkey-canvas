#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

vm_require_command tart

vm_log "Current VM IP: $(vm_tart_ip)"
vm_log "Use macOS Screen Sharing or another VNC client to inspect the guest display."
vm_log "Recommended start mode: HOTKEY_VM_DISPLAY_MODE=vnc scripts/vm/start_worker.sh"
