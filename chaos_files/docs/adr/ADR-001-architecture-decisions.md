# ADR-001: Architecture Decisions for the Chaossynergy Prototype

**Status:** Accepted
**Date:** 2026-07-10
**Author:** Panos (Master) / OrsonRius (Padawan)

## Context

We are building a terminal-first prototype of Chaossynergy — a custom bootc-based operating system image that boots into an agent launcher (Hermes) rather than a traditional desktop. This ADR captures the foundational decisions made before writing any code.

## Decision 1: Base Image — Bluefin DX with NVIDIA

**Decision:** Use `ghcr.io/ublue-os/bluefin-dx-nvidia:stable` as the base image.

**Alternatives considered:**
- `bazzite:stable` — gaming-oriented, wrong target
- `bluefin:stable` — lighter, but lacks dev tools and NVIDIA drivers
- `bluefin-dx:stable` — same dev tools, but no NVIDIA support

**Rationale:**
- Bluefin-dx ships with podman, distrobox, Homebrew, Docker, and most dev tooling pre-installed
- The `-nvidia` variant includes NVIDIA akmods and driver support pre-baked — no extra driver install needed
- We need NVIDIA acceleration for potential future workloads (LLM inference, GPU-accelerated tooling)
- The DX variant is what we already use day-to-day, so the prototype matches our actual environment

**Consequences:**
- Larger image size (~4-5 GB vs ~3 GB for plain bluefin)
- Longer CI build times
- GHCR runners are x86_64 only, so arm64 builds require cross-compilation or separate runners

## Decision 2: Build System — Image-Template (not finpilot)

**Decision:** Keep the existing `image-template` build system for the prototype. Do not migrate to `finpilot` yet.

**Alternatives considered:**
- `finpilot` — the modern multi-stage OCI assembly approach used by Bluefin itself
- `bluebuild` — declarative image builder

**Rationale:**
- The existing CI pipeline (buildah + GitHub Actions + cosign + bootc-image-builder) works and is proven
- Migrating to finpilot would require reworking the Containerfile, understanding OCI assembly patterns, and revalidating the disk-image builder — all before we've even seen the prototype boot
- YAGNI: the multi-stage OCI pattern is a maintenance optimization, not a blocker for the prototype
- We can migrate to finpilot in a later phase once the prototype is validated

**Consequences:**
- We use the single-stage Dockerfile pattern (COPY + RUN)
- Renovate bot updates are per-repo, not on shared OCI components
- Migration path is documented but not urgent

## Decision 3: Hermes Provisioning — First-Boot Systemd Service

**Decision:** The Hermes agent container is created on first boot via a systemd oneshot service, not pre-baked into the image.

**Alternatives considered:**
- **Pre-baked:** Build the Hermes container into the image directly. Zero setup on first boot, but larger image and harder to update independently.
- **First-boot service (chosen):** Image ships with podman + distrobox. On first boot, a systemd service pulls the Hermes image and creates the distrobox container.

**Rationale:**
- Keeps the host image small and the agent container independently updatable
- The user can `distrobox rm hermes && sudo systemctl start setup-hermes` to start fresh
- The agent container is disposable — the host is sacred
- The Hermes container image is maintained separately (ghcr.io/nousresearch/hermes), so updates are decoupled from OS image updates

**Consequences:**
- First boot requires network access to pull the Hermes image
- ~30 seconds of setup time on first boot
- The setup-hermes service only runs on ConditionFirstBoot=yes

## Decision 4: User Interface — Terminal-First (TUI)

**Decision:** The prototype uses a terminal-based launcher (tmux + Hermes) rather than a graphical interface.

**Alternatives considered:**
- **Graphical launcher** (GTK/QML/Electron) — the eventual vision, but months of UI work
- **Web-based launcher** — would require a web server, browser, or Electron
- **TUI (chosen)** — tmux with Hermes in the main pane

**Rationale:**
- Rapid to build: the entire launcher is ~100 lines of bash
- Validates the concept before investing in graphical UI
- The TUI is actually useful — we can use it as a development tool even after the graphical launcher exists
- Bluefin-dx already has GNOME as a fallback desktop, so we're not locked in
- The Steam Deck model starts with a curated launcher, not a desktop

**Consequences:**
- The prototype is terminal-only — no graphical app launcher, no mouse support
- Users who want a desktop can exit the launcher (Ctrl+B d) and access GNOME
- The recovery mode (Shift at boot) provides a root shell for troubleshooting

## Decision 5: Repository Location — GitHub

**Decision:** Keep the repo on GitHub under `github.com/dark5un/chaossynergy`.

**Alternatives considered:**
- GitLab (matching other repos)
- Self-hosted

**Rationale:**
- GitHub Actions is the CI/CD provider for the existing build pipeline
- GitHub Container Registry (GHCR) is where the images are published
- No reason to move until the prototype is validated

**Consequences:**
- None — the repo is already on GitHub, the rename was straightforward

## References

- [bootc documentation](https://github.com/bootc-dev/bootc)
- [Universal Blue](https://universal-blue.org/)
- [Bluefin documentation](https://docs.projectbluefin.io/)
- [image-template](https://github.com/ublue-os/image-template)
- [finpilot](https://github.com/projectbluefin/finpilot)
- [bootc-image-builder](https://github.com/osbuild/bootc-image-builder)