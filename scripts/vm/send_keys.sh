#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/common.sh"

usage() {
    cat <<EOF
Usage: scripts/vm/send_keys.sh <stroke>...

Send key strokes to the guest via CGEvent injection.

Stroke syntax:
  - single key: d
  - modified key: cmd+enter
  - pause: pause:0.5

Supported modifiers:
  cmd, shift, opt, option, alt, ctrl, control

Supported keys:
  a-z, 0-9, enter, return, esc, escape, tab, space,
  up, down, left, right, delete, backspace, period, comma
EOF
}

if [[ $# -eq 0 || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

vm_require_command tart
vm_wait_for_guest

escaped_args=()
for stroke in "$@"; do
    escaped_args+=("$(printf '%q' "${stroke}")")
done
escaped_arg_string="${escaped_args[*]}"

remote_script="$(cat <<'EOF'
set -euo pipefail
cat > /tmp/hotkey-canvas-send-keys.swift <<'SWIFT'
import ApplicationServices
import Foundation

enum StrokeError: Error, CustomStringConvertible {
    case unsupportedStroke(String)
    case unsupportedKey(String)
    case invalidPause(String)

    var description: String {
        switch self {
        case .unsupportedStroke(let stroke):
            return "unsupported stroke: \(stroke)"
        case .unsupportedKey(let key):
            return "unsupported key: \(key)"
        case .invalidPause(let value):
            return "invalid pause: \(value)"
        }
    }
}

struct ModifierDefinition {
    let keyCode: CGKeyCode
    let flag: CGEventFlags
}

let keyCodes: [String: CGKeyCode] = [
    "a": 0x00, "s": 0x01, "d": 0x02, "f": 0x03, "h": 0x04, "g": 0x05,
    "z": 0x06, "x": 0x07, "c": 0x08, "v": 0x09, "b": 0x0B,
    "q": 0x0C, "w": 0x0D, "e": 0x0E, "r": 0x0F, "y": 0x10, "t": 0x11,
    "1": 0x12, "2": 0x13, "3": 0x14, "4": 0x15, "6": 0x16, "5": 0x17,
    "=": 0x18, "9": 0x19, "7": 0x1A, "-": 0x1B, "8": 0x1C, "0": 0x1D,
    "]": 0x1E, "o": 0x1F, "u": 0x20, "[": 0x21, "i": 0x22, "p": 0x23,
    "l": 0x25, "j": 0x26, "'": 0x27, "k": 0x28, ";": 0x29, "\\\\": 0x2A,
    ",": 0x2B, "/": 0x2C, "n": 0x2D, "m": 0x2E, ".": 0x2F,
    "tab": 0x30, "space": 0x31, "delete": 0x33, "backspace": 0x33,
    "enter": 0x24, "return": 0x24, "esc": 0x35, "escape": 0x35,
    "left": 0x7B, "right": 0x7C, "down": 0x7D, "up": 0x7E
]

let modifiers: [String: ModifierDefinition] = [
    "cmd": ModifierDefinition(keyCode: 0x37, flag: .maskCommand),
    "command": ModifierDefinition(keyCode: 0x37, flag: .maskCommand),
    "shift": ModifierDefinition(keyCode: 0x38, flag: .maskShift),
    "opt": ModifierDefinition(keyCode: 0x3A, flag: .maskAlternate),
    "option": ModifierDefinition(keyCode: 0x3A, flag: .maskAlternate),
    "alt": ModifierDefinition(keyCode: 0x3A, flag: .maskAlternate),
    "ctrl": ModifierDefinition(keyCode: 0x3B, flag: .maskControl),
    "control": ModifierDefinition(keyCode: 0x3B, flag: .maskControl),
]

let modifierOrder = ["ctrl", "opt", "shift", "cmd"]
let source = CGEventSource(stateID: .hidSystemState)

func postKey(
    keyCode: CGKeyCode,
    keyDown: Bool,
    flags: CGEventFlags
) {
    guard let source else { return }
    let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown)
    event?.flags = flags
    event?.post(tap: .cghidEventTap)
}

func normalizedModifierOrder(from modifierNames: [String]) -> [String] {
    let unique = Array(Set(modifierNames))
    return modifierOrder.filter { candidate in
        unique.contains { name in
            switch (candidate, name) {
            case ("cmd", "cmd"), ("cmd", "command"),
                 ("shift", "shift"),
                 ("opt", "opt"), ("opt", "option"), ("opt", "alt"),
                 ("ctrl", "ctrl"), ("ctrl", "control"):
                return true
            default:
                return false
            }
        }
    }
}

func sendStroke(_ stroke: String) throws {
    if stroke.hasPrefix("pause:") {
        let rawValue = String(stroke.dropFirst("pause:".count))
        guard let duration = Double(rawValue), duration >= 0 else {
            throw StrokeError.invalidPause(rawValue)
        }
        Thread.sleep(forTimeInterval: duration)
        return
    }

    let parts = stroke
        .split(separator: "+")
        .map { String($0).lowercased() }
        .filter { !$0.isEmpty }
    guard let keyName = parts.last else {
        throw StrokeError.unsupportedStroke(stroke)
    }
    let modifierNames = Array(parts.dropLast())
    let orderedModifiers = normalizedModifierOrder(from: modifierNames)
    for modifierName in modifierNames {
        guard modifiers[modifierName] != nil else {
            throw StrokeError.unsupportedStroke(stroke)
        }
    }
    guard let keyCode = keyCodes[keyName] else {
        throw StrokeError.unsupportedKey(keyName)
    }

    var currentFlags: CGEventFlags = []
    for modifierName in orderedModifiers {
        guard let modifier = modifiers[modifierName] else { continue }
        currentFlags.insert(modifier.flag)
        postKey(keyCode: modifier.keyCode, keyDown: true, flags: currentFlags)
    }
    postKey(keyCode: keyCode, keyDown: true, flags: currentFlags)
    postKey(keyCode: keyCode, keyDown: false, flags: currentFlags)
    for modifierName in orderedModifiers.reversed() {
        guard let modifier = modifiers[modifierName] else { continue }
        currentFlags.remove(modifier.flag)
        postKey(keyCode: modifier.keyCode, keyDown: false, flags: currentFlags)
    }
}

do {
    for stroke in CommandLine.arguments.dropFirst() {
        try sendStroke(stroke)
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
SWIFT
EOF
)"
remote_script="${remote_script}"$'\n'"swift /tmp/hotkey-canvas-send-keys.swift ${escaped_arg_string}"

vm_log "Sending key strokes to ${HOTKEY_VM_NAME}: $*"
vm_tart_exec /bin/zsh -lc "${remote_script}"
