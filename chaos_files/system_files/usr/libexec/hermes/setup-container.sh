#!/bin/bash
# Chaossynergy — First-boot agent container setup
# Creates the distrobox container that runs the agent.
# The container shares the user's home so the agent has the same project context.
# The container is disposable: rm it and re-run this script to start fresh.
set -euo pipefail

DISTROBOX_NAME="agent"
AGENT_IMAGE="ghcr.io/dark5un/chaossynergy-agent:latest"
LOG="${HOME}/.local/log/chaossynergy-setup.log"
mkdir -p "$(dirname "$LOG")"

echo "[chaossynergy] Starting agent container setup..." | tee -a "$LOG"

# Ensure podman socket is running (user-level for rootless)
if ! podman info &>/dev/null; then
    systemctl --user start podman.socket 2>/dev/null || true
    sleep 1
fi

# Pull the custom agent image (Chromium, Node.js, pass, Hermes, etc.)
echo "[chaossynergy] Pulling agent image: $AGENT_IMAGE" | tee -a "$LOG"
podman pull "$AGENT_IMAGE" 2>&1 | tee -a "$LOG"

# Create the distrobox container with privileged access
echo "[chaossynergy] Creating distrobox container..." | tee -a "$LOG"
if distrobox list 2>/dev/null | grep -q "$DISTROBOX_NAME"; then
    echo "[chaossynergy] Container '$DISTROBOX_NAME' already exists, skipping." | tee -a "$LOG"
else
    distrobox create \
        --name "$DISTROBOX_NAME" \
        --image "$AGENT_IMAGE" \
        --additional-flags "--privileged" \
        2>&1 | tee -a "$LOG"
fi

# ── Install herdr inside the agent container ───────────────────────
echo "[chaossynergy] Installing herdr in container..." | tee -a "$LOG"
distrobox enter "$DISTROBOX_NAME" -- bash -c "
  if ! command -v herdr &>/dev/null; then
    curl -fsSL --retry 3 -o /tmp/herdr \
      https://github.com/ogulcancelik/herdr/releases/download/v0.7.3/herdr-linux-x86_64
    install -m 0755 /tmp/herdr /usr/local/bin/herdr
    rm -f /tmp/herdr
  fi
" 2>&1 | tee -a "$LOG"

echo "[chaossynergy] Agent container setup complete." | tee -a "$LOG"
echo "[chaossynergy] Enter it with: distrobox enter agent" | tee -a "$LOG"