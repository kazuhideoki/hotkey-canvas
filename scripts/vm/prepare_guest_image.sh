#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/prepare_guest_image.sh [--install-appium]

Boot a VM first, then run this script to prepare the guest image for UI testing.

Actions:
  - create workspace / artifacts / logs directories
  - optionally install Appium and mac2 driver if npm is available
  - print remaining manual steps for Xcode and TCC
EOF
}

install_appium=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-appium)
            install_appium=true
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

vm_require_command tart
vm_wait_for_guest

remote_script="$(cat <<EOF
set -euo pipefail
mkdir -p '$(vm_guest_workspace_dir)' '${HOTKEY_VM_GUEST_ARTIFACTS_DIR}' '${HOTKEY_VM_GUEST_LOG_DIR}'
echo '[guest] directories prepared'

if command -v brew >/dev/null 2>&1; then
  echo '[guest] brew: available'
else
  echo '[guest] brew: missing'
fi

if command -v npm >/dev/null 2>&1; then
  echo '[guest] npm: available'
else
  echo '[guest] npm: missing'
fi

if ${install_appium}; then
  command -v npm >/dev/null 2>&1 || {
    echo 'error: npm is required to install Appium inside the guest.' >&2
    exit 1
  }
  npm install -g appium
  appium driver install mac2
  echo '[guest] appium + mac2 installed'
fi

cat <<'MANUAL_STEPS'
[guest] manual steps still required:
  1. Install full Xcode and launch it once.
  2. Grant Accessibility / Screen Recording / Automation permissions for the tools that will drive the UI.
  3. Re-run scripts/vm/check_guest_setup.sh after completing these steps.
MANUAL_STEPS
EOF
)"

vm_log "Preparing guest image"
vm_tart_exec /bin/zsh -lc "${remote_script}"
