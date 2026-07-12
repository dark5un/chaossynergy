<p align="center">
  <img src="chaos_files/chaossynergy-wallpaper.png" alt="Chaossynergy" width="100%">
</p>

<h1 align="center">Chaossynergy</h1>
<p align="center">
  <b>The OS is the agent interface.</b><br>
  An agent-native, immutable Linux — purpose-built for human-AI collaboration.
</p>

<p align="center">
  <a href="https://github.com/dark5un/chaossynergy/actions">
    <img src="https://img.shields.io/badge/base-Bluefin%20LTS%20(CentOS%20Stream%2010)-blue" alt="Base">
  </a>
  <a href="LICENSE">
    <img src="https://img.shields.io/badge/license-Apache--2.0-blue" alt="License">
  </a>
</p>

<p align="center">
  <a href="https://chaossynergy.dev">chaossynergy.dev</a>
</p>

---

Chaossynergy is a **Bluefin LTS derivative** — an agent-native, immutable Linux operating system built on CentOS Stream 10.

Two windows. A browser. An agent. Connected at the protocol level.

## Quick Start

```bash
# Build the OS image (30 sec — we build FROM not INCEPT)
just build-chaossynergy stable

# Build a QCOW2 VM image
just build-qcow2 stable
```

Or pull from the registry:

```bash
sudo bootc switch ghcr.io/dark5un/chaossynergy:stable
sudo systemctl reboot
```

## What's inside

A thin overlay on Bluefin LTS:

```dockerfile
FROM ghcr.io/projectbluefin/bluefin-lts:stable
COPY chaos_files/ /tmp/chaos/
RUN bash /tmp/chaos/build.sh
```

The overlay adds:
- **herdr** — agent-native terminal multiplexer, fullscreen on boot
- **user-setup** — first-login automation (pass init, wallpaper, terminal theme)
- **branding** — Chaossynergy wallpaper, icon, Anaconda identity
- **recovery** — Shift-at-boot root shell

## Repository

| Branch | Purpose |
|--------|---------|
| `chaos` | Active image (CentOS Stream 10 base) |
| `chaos-wip` | Previous work (Fedora 44) |
| `chaos-f44` | Fedora 44 fork attempts |

## Architecture

```
┌────────────────────────────────────────────────────────┐
│  Bluefin LTS (CentOS Stream 10)                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Chaossynergy overlay                             │  │
│  │  ├── herdr (fullscreen terminal on boot)         │  │
│  │  ├── user-setup (first login automation)         │  │
│  │  ├── branding (wallpaper, icon)                  │  │
│  │  └── recovery (Shift-at-boot root shell)         │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

## ADRs

Architecture Decision Records live in [`chaos_files/docs/adr/`](chaos_files/docs/adr/).

## License

Apache 2.0

## Built with

Chaossynergy stands on the shoulders of giants:

- **[Bluefin LTS](https://projectbluefin.io/)** — the CentOS Stream 10 immutable OS foundation.
- **[Hermes Agent](https://hermes-agent.nousresearch.com/)** — the open-source AI agent framework by Nous Research.
- **[herdr](https://herdr.dev/)** — the agent-native terminal multiplexer.
- **[CentOS Stream](https://centos.org/)** — the enterprise-grade Linux base.
- **[bootc](https://github.com/containers/bootc)** — bootable container technology.
- **[Browser MCP](https://browsermcp.io/)** — AI-to-browser MCP extension.
- **[pass](https://www.passwordstore.org/)** — the standard Unix password manager.
- **[Chromium](https://www.chromium.org/)** — the open-source browser.