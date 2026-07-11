#!/bin/bash
# Chaossynergy — First-login user setup
# Runs inside the user's GNOME session (via /usr/bin/chaossynergy on first login).
# Exports Chromium from the agent container, configures Hermes MCP,
# applies GNOME desktop tweaks and terminal themes, and creates a pass store if needed.
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
echo "║   Chaossynergy — First Login Setup              ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                  ║"
echo "║  Setting up your agent environment...            ║"
echo "║                                                  ║"
echo "╚══════════════════════════════════════════════════╝"

# ── 1. Export Chromium to host launcher ───────────────────────────
echo "[chaossynergy] Exporting Chromium to host launcher..."
distrobox enter "$CONTAINER" -- distrobox-export --app chromium 2>/dev/null \
    && echo "  ✓ Chromium exported" \
    || echo "  ⚠ Could not export Chromium (might already be done)"

# ── 2. Add Browser MCP to Hermes config ───────────────────────────
HERMES_CONFIG="${HOME}/.hermes/config.yaml"
MCP_ENTRY="browsermcp:"

if [ -f "$HERMES_CONFIG" ]; then
    if grep -q "$MCP_ENTRY" "$HERMES_CONFIG" 2>/dev/null; then
        echo "  ✓ Browser MCP already in Hermes config"
    else
        cat >> "$HERMES_CONFIG" << 'EOF'

# Browser MCP — Hermes controls Chromium via the Browser MCP extension
mcp_servers:
  browsermcp:
    command: "npx"
    args: ["@browsermcp/mcp@latest"]
EOF
        echo "  ✓ Browser MCP added to Hermes config"
    fi
else
    mkdir -p "$(dirname "$HERMES_CONFIG")"
    cat > "$HERMES_CONFIG" << 'EOF'
mcp_servers:
  browsermcp:
    command: "npx"
    args: ["@browsermcp/mcp@latest"]
EOF
    echo "  ✓ Hermes config created with Browser MCP"
fi

# ── 3. Apply GNOME desktop tweaks ─────────────────────────────────
echo "[chaossynergy] Applying GNOME desktop tweaks..."

# Hide the dash/dock for a cleaner agent-first experience
gsettings set org.gnome.shell.extensions.dash-to-dock autohide true 2>/dev/null || true
gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true 2>/dev/null || true
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false 2>/dev/null || true
gsettings set org.gnome.shell.extensions.dash-to-dock show-trash false 2>/dev/null || true
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts false 2>/dev/null || true

echo "  ✓ GNOME dock hidden"

# Set Chaossynergy wallpaper
if [ -f "/usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file:///usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-options 'zoom' 2>/dev/null || true
    echo "  ✓ Chaossynergy wallpaper applied"
fi

# ── 4. Add user to developer groups (docker, libvirt, etc.) ──────
echo "[chaossynergy] Enabling developer mode..."
if command -v bluefin-dx-groups &>/dev/null; then
    bluefin-dx-groups 2>/dev/null && echo "  ✓ Developer groups enabled" || echo "  ⚠ Could not set developer groups (may need re-login)"
elif command -v ujust &>/dev/null; then
    ujust dx-group 2>/dev/null && echo "  ✓ Developer groups enabled" || echo "  ⚠ Could not run ujust dx-group"
else
    # Manual fallback: ensure user is in docker group
    if command -v docker &>/dev/null; then
        sudo usermod -aG docker "$(whoami)" 2>/dev/null || true
        echo "  ✓ Added to docker group"
    fi
fi

# ── 5. Apply alchemical GNOME Terminal profile ────────────────────
echo "[chaossynergy] Applying alchemical terminal theme..."

# Use dconf to create/update the GNOME Terminal profile with
# alchemistic dark colors matching the Chaossynergy brand.
PROFILE_ID=$(gsettings get org.gnome.Terminal.ProfilesList default 2>/dev/null | tr -d "'")
if [ -n "$PROFILE_ID" ]; then
    PROFILE_PATH="/org/gnome/terminal/legacy/profiles:/:${PROFILE_ID}/"
    # Apply dark alchemical palette
    dconf write "${PROFILE_PATH}visible-name" "'Chaossynergy'"
    dconf write "${PROFILE_PATH}use-theme-colors" "false"
    dconf write "${PROFILE_PATH}background-color" "'#050508'"
    dconf write "${PROFILE_PATH}foreground-color" "'#e4e4e7'"
    dconf write "${PROFILE_PATH}cursor-colors-set" "true"
    dconf write "${PROFILE_PATH}cursor-background-color" "'#a78bfa'"
    dconf write "${PROFILE_PATH}cursor-foreground-color" "'#050508'"
    dconf write "${PROFILE_PATH}highlight-colors-set" "true"
    dconf write "${PROFILE_PATH}highlight-background-color" "'#7c5cbf'"
    dconf write "${PROFILE_PATH}highlight-foreground-color" "'#e4e4e7'"
    dconf write "${PROFILE_PATH}bold-color" "'#f59e0b'"
    dconf write "${PROFILE_PATH}use-theme-transparency" "false"
    dconf write "${PROFILE_PATH}use-transparent-background" "false"
    dconf write "${PROFILE_PATH}palette" "['#050508', '#ff5f56', '#27c93f', '#f59e0b', '#a78bfa', '#ff79c6', '#22d3ee', '#e4e4e7', '#555566', '#ff5f56', '#27c93f', '#f59e0b', '#a78bfa', '#ff79c6', '#22d3ee', '#ffffff']"
    dconf write "${PROFILE_PATH}font" "'Fira Code 12'"
    dconf write "${PROFILE_PATH}use-system-font" "false"
    dconf write "${PROFILE_PATH}audible-bell" "false"
    echo "  ✓ Terminal theme applied"
else
    echo "  ⚠ No GNOME Terminal profile found to theme"
fi

# ── 6. Initialize pass (automated if no key exists) ───────────────
PASS_DIR="${HOME}/.password-store"
echo "[chaossynergy] Setting up pass (password-store)..."

if [ -d "$PASS_DIR" ] && [ -f "${PASS_DIR}/.gpg-id" ]; then
    echo "  ✓ pass already initialized with key: $(cat ${PASS_DIR}/.gpg-id)"
else
    # Check if any GPG secret key exists
    EXISTING_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d/ -f2)
    
    if [ -n "$EXISTING_KEY" ]; then
        echo "  Found existing GPG key: $EXISTING_KEY"
        pass init "$EXISTING_KEY" 2>/dev/null && echo "  ✓ pass initialized with existing key" || echo "  ⚠ pass init failed"
    else
        echo "  No GPG key found. Generating one for pass..."
        
        # Generate a GPG key non-interactively for pass
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
            NEW_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d/ -f2)
            rm -f "$GPG_BATCH"
            
            if [ -n "$NEW_KEY" ]; then
                pass init "$NEW_KEY" 2>/dev/null && echo "  ✓ GPG key generated and pass initialized"
                
                # Prompt for API keys
                echo ""
                echo "  ┌─────────────────────────────────────────────────────┐"
                echo "  │  Want to store API keys in pass now?               │"
                echo "  │                                                     │"
                echo "  │  Hermes can read API keys from pass automatically.  │"
                echo "  │  Add keys later with: pass insert hermes/<provider> │"
                echo "  └─────────────────────────────────────────────────────┘"
                echo ""
                
                # Try to store keys interactively
                for provider in openrouter anthropic openai; do
                    echo -n "  Enter $provider API key (or press Enter to skip): "
                    read -r key
                    if [ -n "$key" ]; then
                        echo "$key" | pass insert --multiline hermes/$provider 2>/dev/null && echo "  ✓ $provider stored"
                    fi
                done
            else
                echo "  ⚠ Key generated but couldn't retrieve fingerprint"
            fi
        else
            echo "  ⚠ Could not generate GPG key (needs entropy)"
            echo ""
            echo "  ┌─────────────────────────────────────────────────────┐"
            echo "  │  To set up pass manually:                            │"
            echo "  │                                                     │"
            echo "  │    1. Generate a GPG key:                           │"
            echo "  │       gpg --full-generate-key                       │"
            echo "  │                                                     │"
            echo "  │    2. Initialize pass:                              │"
            echo "  │       pass init <your-gpg-key-id>                   │"
            echo "  │                                                     │"
            echo "  │    3. Store API keys:                               │"
            echo "  │       pass insert hermes/openrouter                 │"
            echo "  └─────────────────────────────────────────────────────┘"
            echo ""
        fi
    fi
fi

# ── Mark setup complete ───────────────────────────────────────────
date > "$SETUP_FLAG"
echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Chaossynergy setup complete!                   ║"
echo "╠══════════════════════════════════════════════════╣"
echo "║                                                  ║"
echo "║  • Chromium is available in the app launcher     ║"
echo "║  • Hermes can control your browser via MCP       ║"
echo "║  • The GNOME dock is hidden for a clean view     ║"
echo "║  • Terminal uses the alchemical Chaossynergy     ║"
echo "║    dark theme                                    ║"
echo "║                                                  ║"
echo "║  Next: herdr is starting...                      ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""