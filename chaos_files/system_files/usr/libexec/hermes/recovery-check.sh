#!/bin/bash
# Chaossynergy — Recovery mode check
# Runs before the launcher. If Shift is held during boot, drops to a root shell.
set -euo pipefail

echo "╔══════════════════════════════════════════════╗"
echo "║         Chaossynergy — Agent OS              ║"
echo "╠══════════════════════════════════════════════╣"
echo "║  Press SHIFT for recovery shell              ║"
echo "║  (or wait 3 seconds to boot normally)        ║"
echo "╚══════════════════════════════════════════════╝"

# Read a single key with 3-second timeout
if command -v timeout &>/dev/null; then
    KEY=$(timeout 3 dd if=/dev/console bs=1 count=1 2>/dev/null || true)
else
    read -t 3 -n 1 KEY || true
fi

if [[ "${KEY:-}" == $'\x1b' ]] || [[ "${KEY:-}" == "S" ]] || [[ "${KEY:-}" == "s" ]]; then
    echo ""
    echo "╔══════════════════════════════════════════════╗"
    echo "║         RECOVERY MODE                        ║"
    echo "╠══════════════════════════════════════════════╣"
    echo "║  You are in a root shell.                    ║"
    echo "║  The agent launcher is disabled.             ║"
    echo "║  Type 'exit' or Ctrl+D to boot normally.     ║"
    echo "╚══════════════════════════════════════════════╝"
    bash
fi