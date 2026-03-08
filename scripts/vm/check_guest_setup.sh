#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

vm_require_command tart
vm_wait_for_guest

remote_script="$(cat <<'EOF'
set -euo pipefail

user_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
system_db="/Library/Application Support/com.apple.TCC/TCC.db"
agent_link="/opt/homebrew/bin/tart-guest-agent"
agent_real=""
if [[ -x "$agent_link" ]]; then
  agent_real="$(/usr/bin/perl -MCwd=realpath -e 'print realpath(shift)' "$agent_link")"
fi

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

check_tcc_row() {
  local label="$1"
  local db="$2"
  local sql="$3"
  local value
  value="$(/usr/bin/sqlite3 "$db" "$sql" 2>/dev/null | /usr/bin/tr -d '[:space:]')"
  if [[ "$value" == "2" ]]; then
    printf '%-24s %s\n' "$label" "ok"
  elif [[ -n "$value" ]]; then
    printf '%-24s %s\n' "$label" "present(auth=$value)"
  else
    printf '%-24s %s\n' "$label" "missing"
  fi
}

if swift - <<'SWIFT' >/dev/null 2>&1
import ApplicationServices
import Darwin
Darwin.exit(AXIsProcessTrusted() ? 0 : 1)
SWIFT
then
  printf '%-24s %s\n' "current-ax-trust" "ok"
else
  printf '%-24s %s\n' "current-ax-trust" "missing"
fi

if [[ -d "/Volumes/My Shared Files" ]]; then
  printf '%-24s %s\n' "virtiofs-share" "ok"
else
  printf '%-24s %s\n' "virtiofs-share" "missing"
fi

if [[ -n "$agent_real" ]]; then
  printf '%-24s %s\n' "agent-real-path" "$agent_real"
  check_tcc_row "agent-appleevents" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServiceAppleEvents' AND client='$agent_real' AND indirect_object_identifier='com.apple.systemevents' ORDER BY last_modified DESC LIMIT 1;"
  check_tcc_row "real-listenevent" "$system_db" "SELECT auth_value FROM access WHERE service='kTCCServiceListenEvent' AND client='$agent_real' ORDER BY last_modified DESC LIMIT 1;"
  check_tcc_row "link-listenevent" "$system_db" "SELECT auth_value FROM access WHERE service='kTCCServiceListenEvent' AND client='$agent_link' ORDER BY last_modified DESC LIMIT 1;"
  check_tcc_row "real-postevent" "$system_db" "SELECT auth_value FROM access WHERE service='kTCCServicePostEvent' AND client='$agent_real' ORDER BY last_modified DESC LIMIT 1;"
  check_tcc_row "link-postevent" "$system_db" "SELECT auth_value FROM access WHERE service='kTCCServicePostEvent' AND client='$agent_link' ORDER BY last_modified DESC LIMIT 1;"
  check_tcc_row "osascript-access" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client='/usr/bin/osascript' ORDER BY last_modified DESC LIMIT 1;"
  check_tcc_row "osascript-events" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServiceAppleEvents' AND client='/usr/bin/osascript' AND indirect_object_identifier='com.apple.systemevents' ORDER BY last_modified DESC LIMIT 1;"
else
  printf '%-24s %s\n' "agent-real-path" "missing"
fi
EOF
)"

vm_log "Checking guest UI automation prerequisites"
vm_tart_exec /bin/zsh -lc "${remote_script}"
