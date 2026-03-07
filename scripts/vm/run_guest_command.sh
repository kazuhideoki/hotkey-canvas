#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

if [[ $# -eq 0 ]]; then
    vm_die "usage: scripts/vm/run_guest_command.sh <command> [args...]"
fi

vm_require_command tart
vm_wait_for_ssh
vm_ssh "$@"
