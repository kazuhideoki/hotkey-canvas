#!/usr/bin/env bash
set -euo pipefail

VM_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_REPO_ROOT="$(cd "${VM_COMMON_DIR}/../.." && pwd)"

HOTKEY_VM_GOLDEN_IMAGE="${HOTKEY_VM_GOLDEN_IMAGE:-hotkey-canvas-golden}"
HOTKEY_VM_NAME="${HOTKEY_VM_NAME:-hotkey-canvas-agent}"
HOTKEY_VM_SSH_USER="${HOTKEY_VM_SSH_USER:-agent}"
HOTKEY_VM_SSH_CONNECT_TIMEOUT="${HOTKEY_VM_SSH_CONNECT_TIMEOUT:-5}"
HOTKEY_VM_BOOT_TIMEOUT_SECONDS="${HOTKEY_VM_BOOT_TIMEOUT_SECONDS:-120}"
HOTKEY_VM_REMOTE_ROOT="${HOTKEY_VM_REMOTE_ROOT:-/Users/${HOTKEY_VM_SSH_USER}}"
HOTKEY_VM_GUEST_WORKSPACE="${HOTKEY_VM_GUEST_WORKSPACE:-${HOTKEY_VM_REMOTE_ROOT}/workspace/hotkey-canvas}"
HOTKEY_VM_GUEST_ARTIFACTS_DIR="${HOTKEY_VM_GUEST_ARTIFACTS_DIR:-${HOTKEY_VM_REMOTE_ROOT}/artifacts}"
HOTKEY_VM_GUEST_LOG_DIR="${HOTKEY_VM_GUEST_LOG_DIR:-${HOTKEY_VM_REMOTE_ROOT}/logs}"
HOTKEY_VM_LOCAL_ROOT="${HOTKEY_VM_LOCAL_ROOT:-${VM_REPO_ROOT}/.tmp/vm/${HOTKEY_VM_NAME}}"
HOTKEY_VM_LOCAL_HOST_LOG_DIR="${HOTKEY_VM_LOCAL_HOST_LOG_DIR:-${HOTKEY_VM_LOCAL_ROOT}/host}"
HOTKEY_VM_LOCAL_ARTIFACTS_DIR="${HOTKEY_VM_LOCAL_ARTIFACTS_DIR:-${HOTKEY_VM_LOCAL_ROOT}/artifacts}"
HOTKEY_VM_APPIUM_PORT="${HOTKEY_VM_APPIUM_PORT:-4723}"
HOTKEY_VM_APPIUM_BASE_PATH="${HOTKEY_VM_APPIUM_BASE_PATH:-/wd/hub}"
HOTKEY_VM_DEBUG_STATE_PORT="${HOTKEY_VM_DEBUG_STATE_PORT:-8750}"
HOTKEY_VM_DEBUG_STATE_TOKEN="${HOTKEY_VM_DEBUG_STATE_TOKEN:-codex-vm-token}"
HOTKEY_VM_DISPLAY_MODE="${HOTKEY_VM_DISPLAY_MODE:-vnc}"
HOTKEY_VM_TART_RUN_EXTRA_ARGS="${HOTKEY_VM_TART_RUN_EXTRA_ARGS:-}"
HOTKEY_VM_SHARED_REPO_NAME="${HOTKEY_VM_SHARED_REPO_NAME:-repo}"
HOTKEY_VM_SHARED_REPO_HOST_PATH="${HOTKEY_VM_SHARED_REPO_HOST_PATH:-${VM_REPO_ROOT}}"
HOTKEY_VM_SHARED_REPO_MODE="${HOTKEY_VM_SHARED_REPO_MODE:-ro}"
HOTKEY_VM_SYNC_DELETE="${HOTKEY_VM_SYNC_DELETE:-1}"

vm_log() {
    printf '[vm] %s\n' "$*"
}

vm_error() {
    printf 'error: %s\n' "$*" >&2
}

vm_die() {
    vm_error "$*"
    exit 1
}

vm_require_command() {
    local command_name="$1"

    if ! command -v "${command_name}" >/dev/null 2>&1; then
        vm_die "required command not found: ${command_name}"
    fi
}

vm_ensure_local_dirs() {
    mkdir -p "${HOTKEY_VM_LOCAL_HOST_LOG_DIR}" "${HOTKEY_VM_LOCAL_ARTIFACTS_DIR}"
}

vm_refresh_local_paths() {
    HOTKEY_VM_LOCAL_ROOT="${VM_REPO_ROOT}/.tmp/vm/${HOTKEY_VM_NAME}"
    HOTKEY_VM_LOCAL_HOST_LOG_DIR="${HOTKEY_VM_LOCAL_ROOT}/host"
    HOTKEY_VM_LOCAL_ARTIFACTS_DIR="${HOTKEY_VM_LOCAL_ROOT}/artifacts"
}

vm_normalize_http_base_path() {
    local base_path="${1:-/}"

    if [[ -z "${base_path}" ]]; then
        base_path="/"
    fi

    if [[ "${base_path}" != /* ]]; then
        base_path="/${base_path}"
    fi

    if [[ "${base_path}" != "/" ]]; then
        base_path="${base_path%/}"
    fi

    printf '%s' "${base_path}"
}

vm_shared_repo_guest_root() {
    printf '/Volumes/My Shared Files/%s' "${HOTKEY_VM_SHARED_REPO_NAME}"
}

vm_build_dir_share_spec() {
    if [[ -z "${HOTKEY_VM_SHARED_REPO_HOST_PATH}" ]]; then
        return 0
    fi

    case "${HOTKEY_VM_SHARED_REPO_MODE}" in
        ro)
            printf '%s:%s:ro' "${HOTKEY_VM_SHARED_REPO_NAME}" "${HOTKEY_VM_SHARED_REPO_HOST_PATH}"
            ;;
        rw)
            printf '%s:%s' "${HOTKEY_VM_SHARED_REPO_NAME}" "${HOTKEY_VM_SHARED_REPO_HOST_PATH}"
            ;;
        *)
            vm_die "unsupported HOTKEY_VM_SHARED_REPO_MODE: ${HOTKEY_VM_SHARED_REPO_MODE}"
            ;;
    esac
}

vm_validate_display_mode() {
    case "${HOTKEY_VM_DISPLAY_MODE}" in
        no-graphics | vnc | vnc-experimental | gui)
            ;;
        *)
            vm_die "unsupported HOTKEY_VM_DISPLAY_MODE: ${HOTKEY_VM_DISPLAY_MODE}"
            ;;
    esac
}

vm_appium_status_url() {
    local base_path
    base_path="$(vm_normalize_http_base_path "${HOTKEY_VM_APPIUM_BASE_PATH}")"

    if [[ "${base_path}" == "/" ]]; then
        printf 'http://127.0.0.1:%s/status' "${HOTKEY_VM_APPIUM_PORT}"
        return
    fi

    printf 'http://127.0.0.1:%s%s/status' "${HOTKEY_VM_APPIUM_PORT}" "${base_path}"
}

vm_debug_state_url() {
    local endpoint="${1:-/debug/v1/health}"

    if [[ "${endpoint}" != /* ]]; then
        endpoint="/${endpoint}"
    fi

    printf 'http://127.0.0.1:%s%s' "${HOTKEY_VM_DEBUG_STATE_PORT}" "${endpoint}"
}

vm_rsync_ssh_command() {
    printf 'ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=%s' "${HOTKEY_VM_SSH_CONNECT_TIMEOUT}"
}

vm_tart_ip() {
    local ip_output
    ip_output="$(tart ip "${HOTKEY_VM_NAME}" 2>/dev/null || true)"
    printf '%s' "${ip_output}" | tr -d '[:space:]'
}

vm_guest_target() {
    local ip_address
    ip_address="$(vm_tart_ip)"

    if [[ -z "${ip_address}" ]]; then
        vm_die "failed to resolve an IP address for VM ${HOTKEY_VM_NAME}"
    fi

    printf '%s@%s' "${HOTKEY_VM_SSH_USER}" "${ip_address}"
}

vm_ssh() {
    local target
    target="$(vm_guest_target)"
    local ssh_options=(
        -o BatchMode=yes
        -o StrictHostKeyChecking=no
        -o UserKnownHostsFile=/dev/null
        -o ConnectTimeout="${HOTKEY_VM_SSH_CONNECT_TIMEOUT}"
    )

    ssh "${ssh_options[@]}" "${target}" "$@"
}

vm_wait_for_ssh() {
    local deadline=$((SECONDS + HOTKEY_VM_BOOT_TIMEOUT_SECONDS))

    while (( SECONDS < deadline )); do
        if [[ -n "$(vm_tart_ip)" ]] && vm_ssh /usr/bin/true >/dev/null 2>&1; then
            return 0
        fi

        sleep 2
    done

    vm_die "VM ${HOTKEY_VM_NAME} did not become reachable over SSH within ${HOTKEY_VM_BOOT_TIMEOUT_SECONDS}s"
}

vm_wait_for_http() {
    local url="$1"
    local auth_header="${2:-}"
    local deadline=$((SECONDS + HOTKEY_VM_BOOT_TIMEOUT_SECONDS))

    while (( SECONDS < deadline )); do
        if [[ -n "${auth_header}" ]]; then
            if vm_ssh /usr/bin/curl -fsS -H "${auth_header}" "${url}" >/dev/null 2>&1; then
                return 0
            fi
        else
            if vm_ssh /usr/bin/curl -fsS "${url}" >/dev/null 2>&1; then
                return 0
            fi
        fi

        sleep 2
    done

    vm_die "timed out waiting for ${url}"
}
