#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

vm_require_command tart
vm_wait_for_guest

remote_script="$(cat <<'EOF'
set -euo pipefail

check_command() {
  local label="$1"
  local command_name="$2"
  if command -v "${command_name}" >/dev/null 2>&1; then
    printf '%-24s %s\n' "${label}" "ok"
  else
    printf '%-24s %s\n' "${label}" "missing"
  fi
}

check_command "swift" "swift"
check_command "xcodebuild" "xcodebuild"
check_command "curl" "curl"
check_command "npm" "npm"
check_command "appium" "appium"
check_command "ffmpeg" "ffmpeg"

if command -v appium >/dev/null 2>&1; then
  if appium driver list --installed 2>/dev/null | grep -q 'mac2'; then
    printf '%-24s %s\n' "appium-mac2-driver" "ok"
  else
    printf '%-24s %s\n' "appium-mac2-driver" "missing"
  fi
else
  printf '%-24s %s\n' "appium-mac2-driver" "missing"
fi

if swift - <<'SWIFT' >/dev/null 2>&1
import ApplicationServices
import Darwin
Darwin.exit(AXIsProcessTrusted() ? 0 : 1)
SWIFT
then
  printf '%-24s %s\n' "accessibility-trust" "ok"
else
  printf '%-24s %s\n' "accessibility-trust" "missing"
fi

if [[ -d "/Volumes/My Shared Files" ]]; then
  printf '%-24s %s\n' "virtiofs-share" "ok"
else
  printf '%-24s %s\n' "virtiofs-share" "missing"
fi
EOF
)"

vm_log "Checking guest UI automation prerequisites"
vm_tart_exec /bin/zsh -lc "${remote_script}"
