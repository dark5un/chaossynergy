# ADR-008: Desktop Experience — GNOME Autostart with Fullscreen Terminal

**Status:** Accepted
**Date:** 2026-07-11
**Author:** Panagiotis Xynos (Master) / OrsonRius (Padawan)

## Context

Chaossynergy's user experience centers on two applications: a browser (Chromium) and an agent terminal (herdr + Hermes). The user should boot into an environment where these are immediately available, with minimal desktop chrome.

The existing prototype used a systemd service (`chaossynergy-launcher.service`) to start herdr, but systemd services lack a terminal — herdr is a TUI and needs a TTY.

## Decision 1: GNOME Autostart with Fullscreen Terminal

**Decision:** Launch herdr via a GNOME autostart `.desktop` file that opens a fullscreen `gnome-terminal`.

```
Exec=gnome-terminal --full-screen --title="Chaossynergy" -- /usr/bin/chaossynergy
```

**Alternatives considered:**
- **Systemd service (`chaossynergy-launcher.service`)** — No TTY. herdr crashes immediately. Removed the `systemctl enable` call from build.sh.
- **Dedicated VT auto-login** — Boot to tty1 with herdr, GNOME on tty2. More reliable TUI, but fights GNOME's display manager and user switching.
- **Wayland compositor replacement** — Replace GNOME with a window manager (Sway, Hyprland). Too drastic for the prototype. GNOME's accessibility and app compatibility are still valuable.

**Rationale:**
- `gnome-terminal --full-screen` gives herdr the entire screen — no distractions
- User exits herdr → back to GNOME desktop seamlessly
- No display manager configuration needed — uses the standard GNOME login flow
- `.desktop` autostart is the canonical pattern for TUI apps on bootc/Bluefin
- 3-second delay (`X-GNOME-Autostart-Delay=3`) ensures GNOME Shell is ready

## Decision 2: Hidden Dock

**Decision:** Disable/enable the GNOME dash-to-dock via gsettings in `user-setup.sh`:

```
gsettings set org.gnome.shell.extensions.dash-to-dock autohide true
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
```

**Rationale:**
- The dock takes visual space away from the two-window layout (browser + terminal)
- Hidden dock can still be revealed by moving the mouse to the screen edge or pressing the Super key
- The Activities overview remains fully accessible
- gsettings is per-user, applied on first login — doesn't affect other users

## Decision 3: Keyboard-Driven Tiling (Built-in GNOME)

**Decision:** Use GNOME's built-in window tiling (`Super+Left` / `Super+Right`) for the two-window layout rather than a third-party tiling extension.

**Alternatives considered:**
- **Forge GNOME extension** — Full auto-tiling like i3 within GNOME. Extra maintenance burden.
- **Pop Shell** — System76's tiling, well-polished but another extension to maintain.
- **Sway/Hyprland** — Replace GNOME entirely. Too early for the prototype.

**Rationale:**
- The built-in tiling is sufficient for two windows side-by-side
- No extra extension to maintain, update, or debug
- `Super+Left` snaps Chromium to the left half, `Super+Right` snaps the terminal
- The user can resize the split by dragging the divider
- Additional tiling can be added later via extensions when the UX demands it

## Decision 4: User Setup on First Login

**Decision:** Run `user-setup.sh` on first GNOME login (before launching herdr) to configure the user environment.

`user-setup.sh` handles:
1. `distrobox-export --app chromium` — exports Chromium to the host launcher
2. Adding `mcp_servers.browsermcp` to `~/.hermes/config.yaml`
3. Applying GNOME gsettings (dock hiding)
4. Detecting pass initialization and guiding the user if not set up

The script is idempotent — it tracks completion via `~/.config/chaossynergy/setup-done`.

**Rationale:**
- Systemd oneshot runs as root — can't set per-user gsettings, can't export apps from a user-owned container
- The user-setup runs inside the user's GNOME session with full access to dconf, gsettings, and the running distrobox
- Once per machine, then never again — subsequent boots skip straight to herdr

## Consequences

- The GNOME autostart `.desktop` replaces the systemd launcher service. The service file is kept in the image for manual use but not enabled.
- Fullscreen terminal = no visible window decorations. User exits herdr to see GNOME chrome.
- Hidden dock = first-time users may wonder where the app launcher went. Addressed by `user-setup.sh`'s informational output.
- `user-setup.sh` output appears inside the terminal that's about to launch herdr — the user sees the setup messages as part of the boot flow.

## References

- [Bluefin documentation](https://docs.projectbluefin.io/)
- [distrobox-export](https://distrobox.it/usage/distrobox-export/)
- [GNOME autostart specification](https://specifications.freedesktop.org/autostart-spec/autostart-spec-latest.html)
- [ADR-005](ADR-005-minimal-host-container-first.md) — Container-first architecture
- [ADR-006](ADR-006-browser-mcp-integration.md) — Browser and MCP integration
