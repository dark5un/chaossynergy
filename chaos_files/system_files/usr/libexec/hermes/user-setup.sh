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

# ── 3. Clean GNOME desktop (dark mode, hide dock, minimal chrome) ──
echo "[chaossynergy] Enforcing dark mode and clean layout..."

# Force GNOME to dark mode (Ptyxis and GTK apps follow this)
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' 2>/dev/null || true

# Disable dash-to-dock for unobstructed desktop
gnome-extensions disable dash-to-dock@micxgx.gmail.com 2>/dev/null || \
  gnome-extensions disable ubuntu-dock@ubuntu.com 2>/dev/null || \
  dconf write /org/gnome/shell/extensions/dash-to-dock/dock-fixed false 2>/dev/null || true
echo "  ✓ Dock hidden"

# ── 4. Apply Chaossynergy wallpaper ────────────────────────────────

# Set Chaossynergy wallpaper
if [ -f "/usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png" ]; then
    gsettings set org.gnome.desktop.background picture-uri "file:///usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-uri-dark "file:///usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png" 2>/dev/null || true
    gsettings set org.gnome.desktop.background picture-options 'zoom' 2>/dev/null || true
    echo "  ✓ Chaossynergy wallpaper applied"
fi

# ── 4. Add user to developer groups ───────────────────────────────
echo "[chaossynergy] Enabling developer mode..."
usermod -aG docker "$(whoami)" 2>/dev/null || \
  echo "  ⚠ docker group not available (skip)"
echo "  ✓ Developer groups done"

# ── 5. Apply alchemical Ptyxis dark theme ──────────────────────────
echo "[chaossynergy] Applying alchemical dark terminal theme..."

# Apply dark alchemical palette to Ptyxis profile
PROFILE_UUID=$(gsettings get org.gnome.Ptyxis default-profile-uuid 2>/dev/null | tr -d "'") || PROFILE_UUID=""
if [ -n "$PROFILE_UUID" ]; then
    PROFILE_PATH="/org/gnome/Ptyxis/Profiles/${PROFILE_UUID}/"
    # Dark background alchemical theme
    dconf write "${PROFILE_PATH}use-theme-colors" "false" 2>/dev/null || true
    dconf write "${PROFILE_PATH}background-color" "'rgb(26,26,46)'" 2>/dev/null || true
    dconf write "${PROFILE_PATH}foreground-color" "'rgb(224,224,224)'" 2>/dev/null || true
    # Synthwave Alpha — built-in named palette in Ptyxis
    dconf write "${PROFILE_PATH}palette" "'Synthwave Alpha'" 2>/dev/null || true
    gsettings set org.gnome.Ptyxis use-system-font false 2>/dev/null || true
    gsettings set org.gnome.Ptyxis font-name 'JetBrainsMono Nerd Font 12' 2>/dev/null || true
    echo "  ✓ Ptyxis dark theme applied"
else
    # Fallback: write a GtkSourceView style scheme
    mkdir -p "${HOME}/.local/share/ptyxis/styles"
    cat > "${HOME}/.local/share/ptyxis/styles/chaossynergy.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<style-scheme id="chaossynergy" _name="Chaossynergy" version="1.0">
  <author>Chaossynergy</author>
  <_description>Alchemistic dark theme</_description>
  <color id="background" value="#050508"/>
  <color id="foreground" value="#e4e4e7"/>
  <color id="term_black" value="#050508"/>
  <color id="term_red" value="#ff5f56"/>
  <color id="term_green" value="#27c93f"/>
  <color id="term_yellow" value="#f59e0b"/>
  <color id="term_blue" value="#a78bfa"/>
  <color id="term_magenta" value="#ff79c6"/>
  <color id="term_cyan" value="#22d3ee"/>
  <color id="term_white" value="#e4e4e7"/>
  <color id="term_bright_black" value="#555566"/>
  <color id="term_bright_red" value="#ff5f56"/>
  <color id="term_bright_green" value="#27c93f"/>
  <color id="term_bright_yellow" value="#f59e0b"/>
  <color id="term_bright_blue" value="#a78bfa"/>
  <color id="term_bright_magenta" value="#ff79c6"/>
  <color id="term_bright_cyan" value="#22d3ee"/>
  <color id="term_bright_white" value="#ffffff"/>
  <style name="text" foreground="foreground" background="background"/>
</style-scheme>
EOF
    echo "  ⚠ No Ptyxis profile found (style file saved for manual import)"
fi

# ── 6. Initialize pass (automated if no key exists) ───────────────
PASS_DIR="${HOME}/.password-store"
echo "[chaossynergy] Setting up pass (password-store)..."

if [ -d "$PASS_DIR" ] && [ -f "${PASS_DIR}/.gpg-id" ]; then
    echo "  ✓ pass already initialized with key: $(cat ${PASS_DIR}/.gpg-id)"
else
    # Check if any GPG secret key exists
    EXISTING_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d/ -f2) || true
    
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
            NEW_KEY=$(gpg --list-secret-keys --keyid-format LONG 2>/dev/null | grep "^sec" | head -1 | awk '{print $2}' | cut -d/ -f2) || true
            rm -f "$GPG_BATCH"
            
            if [ -n "$NEW_KEY" ]; then
                pass init "$NEW_KEY" 2>/dev/null && echo "  ✓ GPG key generated and pass initialized"
            else
                echo "  ⚠ Key generated but couldn't retrieve fingerprint"
            fi
        else
            echo "  ⚠ Could not generate GPG key (needs entropy)"
            echo "  Run 'gpg --full-generate-key' and 'pass init <key-id>' manually later."
        fi
    fi
fi

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

# ── Run Hermes setup (interactive — configures providers, API keys) ──
echo "[chaossynergy] Launching Hermes setup..."
distrobox enter agent -- hermes setup 2>/dev/null || \
  echo "  ⚠ Hermes setup skipped — run 'hermes setup' manually later."

# ── Trigger reboot ────────────────────────────────────────────────
echo "Chaossynergy setup complete. Rebooting in 15s..."
echo "Press Ctrl+C to cancel."
# Mark setup done before rebooting
date > "$SETUP_FLAG"
sleep 15
systemctl reboot -i || sudo reboot || loginctl reboot