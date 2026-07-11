#!/bin/bash
# Chaossynergy — First-boot agent container setup
# Creates the distrobox container that runs the agent.
# The container shares the user's home so the agent has the same project context.
# The container is disposable: rm it and re-run this script to start fresh.
set -euo pipefail

DISTROBOX_NAME="agent"
AGENT_IMAGE="ghcr.io/dark5un/chaossynergy-agent:latest"
LOG="/var/log/chaossynergy-setup.log"

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
# so Hermes can drive Docker, podman, and other tools.
# NOTE: No --home flag — shares the user's home directory.
# This gives the agent the same project context, config, and tooling
# as the user, eliminating confusion about where files live.
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

echo "[chaossynergy] Agent container setup complete." | tee -a "$LOG"
echo "[chaossynergy] Enter it with: distrobox enter agent" | tee -a "$LOG"