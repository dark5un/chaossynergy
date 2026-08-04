#!/bin/bash
# Chaossynergy Niri — First-login user setup
# Runs inside the agent session (via /usr/bin/chaossynergy on first launch).
# Exports Chromium from the agent container, configures Hermes MCP,
# creates a pass store if needed. No GNOME-specifics (no gsettings/dconf).
set -euo pipefail

SETUP_FLAG="${HOME}/.config/chaossynergy/setup-done"
CONTAINER="agent"

# ── Check if already done ─────────────────────────────────────────
if [ -f "$SETUP_FLAG" ]; then
    echo "[chaossynergy] Setup already complete. Skipping."
    exit 0
fi

mkdir -p "$(dirname "$SETUP_FLAG")"

echo "╔══════════════════════════════════════════════════╗"
echo "║   Chaossynergy Niri — First Login Setup          ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                  ║"
echo "║  Setting up your agent environment...            ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"

# ── 1. Export Chromium to host launcher ──────────────────────────
echo "[chaossynergy] Exporting Chromium to host launcher..."
distrobox enter "$CONTAINER" -- distrobox-export --app chromium 2>/dev/null \
    && echo "  ✓ Chromium exported" \
    || echo "  ⚠ Could not export Chromium (might already be done)"

# ── 2. Add Browser MCP to Hermes config (inside agent container) ──
echo "[chaossynergy] Setting up Browser MCP for Hermes..."
distrobox enter agent -- bash -c '
  HERMES_CONFIG="${HOME}/.hermes/config.yaml"
  MCP_ENTRY="browsermcp:"
  mkdir -p "$(dirname "$HERMES_CONFIG")"
  if [ -f "$HERMES_CONFIG" ] && grep -q "$MCP_ENTRY" "$HERMES_CONFIG" 2>/dev/null; then
    echo "  ✓ Browser MCP already in Hermes config"
  else
    cat > "$HERMES_CONFIG" << "MCPEOF"
mcp_servers:
  browsermcp:
    command: "npx"
    args: ["@browsermcp/mcp@latest"]
MCPEOF
    echo "  ✓ Hermes config created with Browser MCP"
  fi
' 2>/dev/null || echo "  ⚠ Could not configure Hermes (container not ready)"

# ── 3. Create Ghostty user config (theme overrides if desired) ────
mkdir -p "${HOME}/.config/ghostty"
if [ -f "${HOME}/.config/ghostty/config" ]; then
    echo "  ✓ Ghostty config present"
else
    cat > "${HOME}/.config/ghostty/config" << 'EOF'
font-family = "Source Code Pro Nerd Font"
font-size = 13
theme = "tokyonight"
EOF
    echo "  ✓ Ghostty user config created"
fi

# ── 4. Initialize pass (automated if no key exists) ───────────────
PASS_DIR="${HOME}/.password-store"
echo "[chaossynergy] Setting up pass (password-store)..."

if [ -d "$PASS_DIR" ] && [ -f "${PASS_DIR}/.gpg-id" ]; then
    echo "  ✓ pass already initialized with key: $(cat ${PASS_DIR}/.gpg-id)"
else
    EXISTING_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d/ -f2) || true
    if [ -n "$EXISTING_KEY" ]; then
        echo "  Found existing GPG key: $EXISTING_KEY"
        pass init "$EXISTING_KEY" 2>/dev/null && echo "  ✓ pass initialized with existing key" || echo "  ⚠ pass init failed"
    else
        echo "  No GPG key found. Generating one for pass..."
        GPG_BATCH=$(mktemp)
        cat > "$GPG_BATCH" << GPGEOF
%echo Generating Chaossynergy agent GPG key
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: Chaossynergy Agent
Name-Email: agent@chaossynergy.local
Expire-Date: 0
%no-protection
%commit
%echo Done
GPGEOF
        if gpg --batch --gen-key "$GPG_BATCH" 2>/dev/null; then
            NEW_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d/ -f2) || true
            rm -f "$GPG_BATCH"
            if [ -n "$NEW_KEY" ]; then
                pass init "$NEW_KEY" 2>/dev/null && echo "  ✓ GPG key generated and pass initialized"
            else
                echo "  ⚠ Key generated but couldn't retrieve fingerprint"
            fi
        else
            echo "  ⚠ Could not generate GPG key (needs entropy)"
        fi
    fi
fi

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Chaossynergy Niri setup complete!              ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                  ║"
echo "║  • Chromium exported to the launcher             ║"
echo "║  • Hermes wired to Browser MCP                   ║"
echo "║  • Ghostty uses Source Code Pro Nerd Font        ║"
echo "║                                                  ║"
echo "║  herdr is starting...                            ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# Mark setup done (no reboot — niri session is already up)
date > "$SETUP_FLAG"

# ── Run Hermes setup (interactive — configures providers, API keys) ──
echo "[chaossynergy] Launching Hermes setup..."
distrobox enter agent -- hermes setup 2>/dev/null || \
  echo "  ⚠ Hermes setup skipped — run 'hermes setup' manually later."
