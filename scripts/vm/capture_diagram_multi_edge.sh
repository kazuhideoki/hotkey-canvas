#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/capture_diagram_multi_edge.sh [--edge-count N] [--output RELPATH] [--state-output RELPATH]

Creates a Diagram scenario in the guest without opening a host-side viewer:
  - bootstrap the empty canvas with one tree node
  - add the first diagram node via mode selection
  - add the second diagram node in the same diagram area
  - connect the two diagram nodes repeatedly
  - capture a screenshot and debug-state snapshot

Defaults:
  --edge-count 3
  --output .tmp/vm-artifacts/diagram-multi-edge.png
  --state-output .tmp/vm-artifacts/diagram-multi-edge-state.json
EOF
}

edge_count=3
relative_output_path=".tmp/vm-artifacts/diagram-multi-edge.png"
relative_state_output_path=".tmp/vm-artifacts/diagram-multi-edge-state.json"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --edge-count)
            edge_count="${2:?missing value for --edge-count}"
            shift 2
            ;;
        --output)
            relative_output_path="${2:?missing value for --output}"
            shift 2
            ;;
        --state-output)
            relative_state_output_path="${2:?missing value for --state-output}"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            vm_die "unknown argument: $1"
            ;;
    esac
done

[[ "${edge_count}" =~ ^[0-9]+$ ]] || vm_die "--edge-count must be a non-negative integer"
(( edge_count >= 2 )) || vm_die "--edge-count must be >= 2"

host_state_output_path="${VM_REPO_ROOT}/${relative_state_output_path}"
host_output_path="${VM_REPO_ROOT}/${relative_output_path}"
host_sessions_output_path="${HOTKEY_VM_LOCAL_ARTIFACTS_DIR}/diagram-multi-edge-sessions.json"
host_full_state_output_path="${HOTKEY_VM_LOCAL_ARTIFACTS_DIR}/diagram-multi-edge-full-state.json"

vm_require_command tart
vm_wait_for_guest

remote_reset_script="$(cat <<EOF
set -euo pipefail
pid_file='${HOTKEY_VM_GUEST_LOG_DIR}/hotkey-canvas.pid'
if [[ -f "\${pid_file}" ]] && kill -0 "\$(cat "\${pid_file}")" 2>/dev/null; then
    kill "\$(cat "\${pid_file}")" 2>/dev/null || true
    sleep 1
fi
rm -f "\${pid_file}"
EOF
)"

vm_log "Restarting HotkeyCanvas to get a fresh UI session"
vm_tart_exec /bin/zsh -lc "${remote_reset_script}"
"${script_dir}/start_hotkey_canvas_debug.sh"

scenario_sequence=(
    "pause:2.0"
    "move:500:350"
    "click:1"
    "pause:1.0"
    "shift+enter"
    "pause:1.0"
    "esc"
    "pause:0.8"
    "shift+enter"
    "pause:1.0"
    "d"
    "pause:0.7"
    "enter"
    "pause:1.5"
    "esc"
    "pause:0.8"
    "super+enter"
    "pause:1.5"
    "esc"
    "pause:0.8"
)

additional_edge_count=$((edge_count - 1))
for ((index = 0; index < additional_edge_count; index += 1)); do
    scenario_sequence+=(
        "super+l"
        "pause:1.0"
        "enter"
        "pause:1.5"
    )
done

"${script_dir}/send_vnc_keys.sh" "${scenario_sequence[@]}"

mkdir -p "$(dirname "${host_sessions_output_path}")"
"${script_dir}/fetch_debug_state.sh" /debug/v1/sessions "${host_sessions_output_path}"

selected_session_id="$(
python3 - "${host_sessions_output_path}" "${edge_count}" <<'PY'
import json
import sys

path = sys.argv[1]
required_edges = int(sys.argv[2])
with open(path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

best = None
for session in payload.get("sessions", []):
    node_count = session.get("nodeCount", -1)
    edge_count = session.get("edgeCount", -1)
    if node_count >= 2 and edge_count >= required_edges:
        best = session.get("sessionID")
        break

if best is None:
    raise SystemExit(1)

print(best)
PY
)" || vm_die "debug-state did not report the expected Diagram scenario (>=2 nodes, >=${edge_count} edges)"

"${script_dir}/fetch_debug_state.sh" \
    "/debug/v1/sessions/${selected_session_id}/state" \
    "${host_full_state_output_path}"

"${script_dir}/fetch_debug_state.sh" \
    "/debug/v1/sessions/${selected_session_id}/state" \
    "${host_state_output_path}"

python3 - "${host_full_state_output_path}" "${edge_count}" <<'PY'
import json
import sys

path = sys.argv[1]
required_edges = int(sys.argv[2])
with open(path, "r", encoding="utf-8") as handle:
    payload = json.load(handle)

areas = payload["graph"]["areas"]
nodes = payload["graph"]["nodes"]
edges = payload["graph"]["edges"]
diagram_area_ids = {
    area["id"]
    for area in areas
    if area["editingMode"] == "diagram"
}
node_area_by_id = {}
for area in areas:
    for node_id in area["nodeIDs"]:
        node_area_by_id[node_id] = area["id"]

diagram_node_ids = [
    node["id"]
    for node in nodes
    if node_area_by_id.get(node["id"]) in diagram_area_ids
]
diagram_edge_count = sum(
    1
    for edge in edges
    if node_area_by_id.get(edge["fromNodeID"]) in diagram_area_ids
    and node_area_by_id.get(edge["toNodeID"]) in diagram_area_ids
)

if len(diagram_node_ids) < 2 or diagram_edge_count < required_edges:
    raise SystemExit(
        f"expected >=2 diagram nodes and >={required_edges} diagram edges, "
        f"got {len(diagram_node_ids)} nodes / {diagram_edge_count} edges"
    )
PY

"${script_dir}/capture_screen.sh" "${relative_output_path}"

vm_log "Saved scenario screenshot -> ${host_output_path}"
vm_log "Saved scenario debug-state -> ${host_state_output_path}"
