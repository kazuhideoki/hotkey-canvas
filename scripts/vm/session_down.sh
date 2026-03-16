#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/session_down.sh [options]

Collect optional artifacts and stop the current VM work session.

Options:
  --capture-screen             Save a final screenshot before stopping.
  --save-health                Save /debug/v1/health JSON before stopping.
  --save-sessions              Save /debug/v1/sessions JSON before stopping.
  --collect-standard-artifacts Enable all three artifact options above.
  --help                       Show this help.
EOF
}

capture_screen=false
save_health=false
save_sessions=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --capture-screen)
            capture_screen=true
            ;;
        --save-health)
            save_health=true
            ;;
        --save-sessions)
            save_sessions=true
            ;;
        --collect-standard-artifacts)
            capture_screen=true
            save_health=true
            save_sessions=true
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            vm_die "unknown argument: $1"
            ;;
    esac
    shift
done

vm_ensure_local_dirs
artifact_dir="${HOTKEY_VM_LOCAL_ARTIFACTS_DIR}"
mkdir -p "${artifact_dir}"

collect_best_effort() {
    local description="$1"
    shift
    if ! "$@"; then
        vm_error "best-effort step failed: ${description}"
    fi
}

# Artifact collection is best-effort because teardown should still complete
# even when the app has already stopped or debug-state is no longer reachable.
if [[ "${capture_screen}" == true ]]; then
    collect_best_effort \
        "capture final screen" \
        "${script_dir}/capture_screen.sh" ".tmp/vm/${HOTKEY_VM_NAME}/artifacts/final-screen.png"
fi

if [[ "${save_health}" == true ]]; then
    collect_best_effort \
        "save debug health" \
        "${script_dir}/fetch_debug_state.sh" "/debug/v1/health" "${artifact_dir}/debug-health.json"
fi

if [[ "${save_sessions}" == true ]]; then
    collect_best_effort \
        "save debug sessions" \
        "${script_dir}/fetch_debug_state.sh" "/debug/v1/sessions" "${artifact_dir}/debug-sessions.json"
fi

vm_log "session_down: stop worker VM"
"${script_dir}/stop_worker.sh"

vm_log "session_down: artifacts -> ${artifact_dir}"
vm_log "session_down: host logs -> ${HOTKEY_VM_LOCAL_HOST_LOG_DIR}"
