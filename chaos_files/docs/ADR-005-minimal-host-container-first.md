# ADR-005: Minimal Host — Container-First Architecture

**Status:** Accepted
**Date:** 2026-07-11
**Author:** Panagiotis Xynos (Master) / OrsonRius (Padawan)

## Context

The initial prototype installed everything into the host OS image: Node.js, tmux, and various dev tools. This made the host image larger, harder to maintain, and coupled the agent's runtime dependencies to the host's update cycle.

## Problem

1. **Host image bloat** — Every tool the agent needs (Node.js, browser, password manager, etc.) becomes a build-time dependency of the OS image, increasing build time and image size.
2. **Immutable OS friction** — Bluefin's `/usr/local` is symlinked to `/var/usrlocal`. Tools that expect to install there fail. Packages that need `dnf` on the host permanently alter the OS deployment.
3. **Update coupling** — The agent and its dependencies are tied to the OS image's release cycle. Updating Hermes means rebuilding the whole OS image.
4. **Disposability mismatch** — The host OS is sacred (bootc rollback, signed updates). The agent container should be disposable. Mixing concerns breaks both patterns.

## Decision

Move all agent functionality into the distrobox container. The host image stays minimal — only what's needed to boot into GNOME and launch the container.

### Host image contains only:
- Bluefin DX NVIDIA base
- `herdr` binary (the TUI multiplexer)
- `systemd` services: `setup-agent`, `chaossynergy-recovery`
- GNOME autostart `.desktop` file (fullscreen terminal)
- No browsers, no Node.js, no pass, no Hermes

### Distrobox container (`agent`) contains:
- **Chromium** — the user's browser, exported to the host via `distrobox-export`
- **Node.js + npm** — runtime for the Browser MCP server (`npx @browsermcp/mcp`)
- **Hermes Agent** — installed via the official install script
- **pass + browserpass-native** — GPG-encrypted secrets management
- **Chrome/Chromium policies** — force-installed extensions (Browser MCP, Browserpass)

### Build pipeline:
- `container-files/distrobox/Containerfile` builds the agent container image
- CI workflow `build-agent.yml` publishes to `ghcr.io/dark5un/chaossynergy-agent`
- First-boot systemd service pulls the image and creates the distrobox
- On first login, `user-setup.sh` exports Chromium and configures Hermes MCP

## Rationale

- **Separation of concerns** — The OS image is a stable, minimal platform. The agent container is a flexible, disposable runtime.
- **Update independence** — The agent image can be updated, rebuilt, and pushed without touching the OS image. The user just runs `distrobox rm agent && sudo systemctl start setup-agent`.
- **No immutable OS fights** — Inside Fedora 43, `dnf install` works normally. No `/usr/local` symlink issues.
- **Disposability** — Blow away the container, start fresh. The host remains untouched.
- **Export to host** — `distrobox-export --app chromium` makes container apps appear in the host launcher seamlessly.

## Consequences

- First boot requires network access to pull the agent image (~1GB download for Chromium).
- The agent image needs its own CI pipeline (added via `build-agent.yml`).
- `~/.hermes/config.yaml` lives on the shared host home — shared between host Hermes and container Hermes.
- `~/.password-store` lives on the shared home — accessible from both environments.

## References

- [ADR-003](ADR-003-shared-home-directory.md) — Shared home directory (enables this pattern)
- [distrobox-export](https://distrobox.it/usage/distrobox-export/)
- [Containerfile](https://github.com/dark5un/chaossynergy/blob/develop/container-files/distrobox/Containerfile)
