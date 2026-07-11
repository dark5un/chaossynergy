<p align="center">
  <img src="chaos_files/chaossynergy-wallpaper.png" alt="Chaossynergy" width="100%">
</p>

<h1 align="center">Chaossynergy</h1>
<p align="center">
  <b>The OS is the agent interface.</b><br>
  An agent-native, immutable Linux — purpose-built for human-AI collaboration.
</p>

<p align="center">
  <a href="https://github.com/dark5un/chaossynergy/actions/workflows/build-image-stable.yml">
    <img src="https://github.com/dark5un/chaossynergy/actions/workflows/build-image-stable.yml/badge.svg?branch=chaos" alt="Build">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="License">
  </a>
</p>

<p align="center">
  <a href="https://chaossynergy.dev">chaossynergy.dev</a>
</p>

---

Chaossynergy is a **Bluefin derivative** — an agent-native, immutable Linux operating system. It builds on [Universal Blue](https://universal-blue.org/)'s bootc technology with an overlay that adds a purpose-built agent environment.

Two windows. A browser. An agent. Connected at the protocol level.

## Quick Start

```bash
# Build the OS image
sudo -E $(command -v just) build chaossynergy stable main

# Build a QCOW2 VM image
just build-qcow2 localhost/chaossynergy stable
```

Or deploy from the registry:

```bash
sudo bootc switch ghcr.io/dark5un/chaossynergy:stable
sudo systemctl reboot
```

## What's inside

The `chaos` branch tracks `ublue-os/bluefin` upstream `main` with a clean overlay in `chaos_files/`. See [chaos_files/build.sh](chaos_files/build.sh) for what we add.

## Architecture

```
┌───────────────────────────────────────────────────────────┐
│  Bluefin (silverblue-main) — immutable bootc host         │
│                                                            │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  Chaossynergy overlay                                 │  │
│  │  ├── herdr (fullscreen terminal on boot)             │  │
│  │  ├── agent distrobox (Chromium + Hermes + pass)      │  │
│  │  ├── user-setup (first login automation)             │  │
│  │  ├── branding (wallpaper, icon, Anaconda identity)   │  │
│  │  └── recovery (Shift-at-boot root shell)             │  │
│  └─────────────────────────────────────────────────────┘  │
└───────────────────────────────────────────────────────────┘
```

## Repository

| Branch | Tracks | Purpose |
|--------|--------|---------|
| `chaos` | `ublue-os/bluefin:main` + overlay | Our active image |
| `main` | (forked, kept for history) | Bluefin upstream |

### Rebase on upstream

```bash
git remote add upstream https://github.com/ublue-os/bluefin
git fetch upstream
git rebase upstream/main
git push origin chaos
```

## ADRs

Architecture Decision Records live in [`chaos_files/docs/adr/`](chaos_files/docs/adr/).

## License

Apache 2.0

## Built with

Chaossynergy stands on the shoulders of giants:

- **[Universal Blue](https://universal-blue.org/)** — the bootc-based image ecosystem. Bluefin, the image-template CI, and the community around bootc containers are the foundation.
- **[Hermes Agent](https://hermes-agent.nousresearch.com/)** — the open-source AI agent framework by Nous Research.
- **[herdr](https://herdr.dev/)** — the agent-native terminal multiplexer.
- **[bootc](https://github.com/containers/bootc)** — bootable container technology.
- **[distrobox](https://distrobox.it/)** — disposable agent runtime containers.
- **[Browser MCP](https://browsermcp.io/)** — AI-to-browser MCP extension.
- **[browserpass](https://github.com/browserpass/browserpass-extension)** — browser extension for pass.
- **[pass](https://www.passwordstore.org/)** — the standard Unix password manager.
- **[Chromium](https://www.chromium.org/)** — the open-source browser.