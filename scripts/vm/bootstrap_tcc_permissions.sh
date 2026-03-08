#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/bootstrap_tcc_permissions.sh

Normalizes TCC rows for VM UI automation after the guest has been manually seeded once.

This script:
  - reuses the user-approved tart-guest-agent AppleEvents row as the anchor
  - populates matching osascript rows in the user TCC database
  - mirrors tart-guest-agent rows across both the real Cellar path and /opt/homebrew/bin symlink
  - updates the system TCC database for event-posting services when sudo is available

This script cannot:
  - click macOS permission prompts for you
  - create the first tart-guest-agent approval rows from nothing

Before running this, connect to the guest over VNC and complete once:
  1. Allow tart-guest-agent to control System Events.
  2. Enable tart-guest-agent for event injection in Privacy & Security if macOS opens it.
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

vm_require_command tart
vm_wait_for_guest

remote_script="$(cat <<'EOF'
set -euo pipefail

user_db="$HOME/Library/Application Support/com.apple.TCC/TCC.db"
system_db="/Library/Application Support/com.apple.TCC/TCC.db"
agent_link="/opt/homebrew/bin/tart-guest-agent"

if [[ ! -f "$user_db" ]]; then
  echo "error: user TCC database was not found: $user_db" >&2
  exit 1
fi

if [[ ! -x "$agent_link" ]]; then
  echo "error: tart-guest-agent was not found at $agent_link" >&2
  exit 1
fi

agent_real="$(/usr/bin/perl -MCwd=realpath -e 'print realpath(shift)' "$agent_link")"
now="$(/bin/date +%s)"

query_value() {
  local db="$1"
  local sql="$2"
  /usr/bin/sqlite3 "$db" "$sql"
}

print_row_status() {
  local label="$1"
  local db="$2"
  local sql="$3"
  local value
  value="$(query_value "$db" "$sql" 2>/dev/null | /usr/bin/tr -d '[:space:]')"
  if [[ "$value" == "2" ]]; then
    printf '%-30s %s\n' "$label" "ok"
  elif [[ -n "$value" ]]; then
    printf '%-30s %s\n' "$label" "present(auth=$value)"
  else
    printf '%-30s %s\n' "$label" "missing"
  fi
}

agent_appleevents_csreq_hex="$(
  query_value "$user_db" \
    "SELECT hex(csreq) FROM access WHERE service='kTCCServiceAppleEvents' AND client='$agent_real' AND client_type=1 AND indirect_object_identifier='com.apple.systemevents' AND auth_value=2 ORDER BY last_modified DESC LIMIT 1;"
)"

if [[ -z "$agent_appleevents_csreq_hex" ]]; then
  cat <<MANUAL >&2
error: tart-guest-agent AppleEvents approval was not found in the user TCC database.

Seed it once while VNC is connected:
  1. Trigger the prompt from the host:
       tart exec ${HOTKEY_VM_NAME:-<vm-name>} /bin/zsh -lc 'osascript -e "tell application \"System Events\" to keystroke \"x\""'
  2. In the guest, click "Allow".
  3. Re-run scripts/vm/bootstrap_tcc_permissions.sh
MANUAL
  exit 1
fi

event_csreq_hex="$(
  sudo /usr/bin/sqlite3 "$system_db" \
    "SELECT hex(csreq) FROM access WHERE client='$agent_real' AND service IN ('kTCCServicePostEvent','kTCCServiceListenEvent') AND auth_value=2 AND csreq IS NOT NULL ORDER BY last_modified DESC LIMIT 1;" \
    2>/dev/null || true
)"

if [[ -z "$event_csreq_hex" ]]; then
  event_csreq_hex="$agent_appleevents_csreq_hex"
  echo "[guest] warning: system TCC event rows were not manually seeded yet; reusing the AppleEvents csreq as a best-effort fallback."
fi

osascript_req="$(
  /usr/bin/codesign -d -r- /usr/bin/osascript 2>&1 |
  /usr/bin/sed -n 's/^designated => //p'
)"
printf '%s' "$osascript_req" > /tmp/osascript.req
/usr/bin/csreq -r /tmp/osascript.req -b /tmp/osascript.csreq
osascript_csreq_hex="$(
  /usr/bin/xxd -p /tmp/osascript.csreq |
  /usr/bin/tr -d '\n'
)"

/usr/bin/sqlite3 "$user_db" <<SQL
BEGIN;
INSERT OR REPLACE INTO access
(service,client,client_type,auth_value,auth_reason,auth_version,csreq,policy_id,indirect_object_identifier_type,indirect_object_identifier,indirect_object_code_identity,flags,last_modified,pid,pid_version,boot_uuid,last_reminded)
VALUES
('kTCCServiceAccessibility','com.apple.systemevents',0,2,4,1,NULL,NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceAppleEvents','$agent_real',1,2,4,1,X'$agent_appleevents_csreq_hex',NULL,0,'com.apple.systemevents',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceAppleEvents','$agent_link',1,2,4,1,X'$agent_appleevents_csreq_hex',NULL,0,'com.apple.systemevents',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceAccessibility','$agent_real',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceAccessibility','$agent_link',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceListenEvent','$agent_real',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceListenEvent','$agent_link',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServicePostEvent','$agent_real',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServicePostEvent','$agent_link',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceAccessibility','/usr/bin/osascript',1,2,4,1,X'$osascript_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceAppleEvents','/usr/bin/osascript',1,2,4,1,X'$osascript_csreq_hex',NULL,0,'com.apple.systemevents',NULL,0,$now,NULL,NULL,'UNUSED',$now);
COMMIT;
SQL

if sudo -n true >/dev/null 2>&1; then
  sudo /usr/bin/sqlite3 "$system_db" <<SQL
BEGIN;
INSERT OR REPLACE INTO access
(service,client,client_type,auth_value,auth_reason,auth_version,csreq,policy_id,indirect_object_identifier_type,indirect_object_identifier,indirect_object_code_identity,flags,last_modified,pid,pid_version,boot_uuid,last_reminded)
VALUES
('kTCCServiceListenEvent','$agent_real',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServiceListenEvent','$agent_link',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServicePostEvent','$agent_real',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now),
('kTCCServicePostEvent','$agent_link',1,2,4,1,X'$event_csreq_hex',NULL,0,'UNUSED',NULL,0,$now,NULL,NULL,'UNUSED',$now);
COMMIT;
SQL
else
  echo "[guest] warning: sudo without password is unavailable; system TCC rows were not updated."
fi

killall tccd >/dev/null 2>&1 || true
sudo -n killall tccd >/dev/null 2>&1 || true
killall "System Events" >/dev/null 2>&1 || true

printf '%-30s %s\n' "agent-real-path" "$agent_real"
print_row_status "user agent-appleevents" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServiceAppleEvents' AND client='$agent_real' AND indirect_object_identifier='com.apple.systemevents' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "user agent-accessibility" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client='$agent_real' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "user agent-listenevent" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServiceListenEvent' AND client='$agent_real' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "user agent-postevent" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServicePostEvent' AND client='$agent_real' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "system real-listenevent" "$system_db" "SELECT auth_value FROM access WHERE service='kTCCServiceListenEvent' AND client='$agent_real' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "system link-listenevent" "$system_db" "SELECT auth_value FROM access WHERE service='kTCCServiceListenEvent' AND client='$agent_link' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "system real-postevent" "$system_db" "SELECT auth_value FROM access WHERE service='kTCCServicePostEvent' AND client='$agent_real' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "system link-postevent" "$system_db" "SELECT auth_value FROM access WHERE service='kTCCServicePostEvent' AND client='$agent_link' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "user osascript-access" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServiceAccessibility' AND client='/usr/bin/osascript' ORDER BY last_modified DESC LIMIT 1;"
print_row_status "user osascript-events" "$user_db" "SELECT auth_value FROM access WHERE service='kTCCServiceAppleEvents' AND client='/usr/bin/osascript' AND indirect_object_identifier='com.apple.systemevents' ORDER BY last_modified DESC LIMIT 1;"
EOF
)"

vm_log "Bootstrapping guest TCC rows"
vm_tart_exec /bin/zsh -lc "${remote_script}"
