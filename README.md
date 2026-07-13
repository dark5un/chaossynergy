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
- **ujust recipes** — on-demand agent and inference setup

## Agents & Inference

All agents live in their own distrobox containers (per ADR-004). Install on demand with `ujust`:

| Command | What it sets up |
|---------|----------------|
| `ujust setup-opencode` | OpenCode coding agent |
| `ujust setup-pi` | Pi coding agent (pi.dev) |
| `ujust setup-claude` | Claude Code coding agent |
| `ujust setup-inference-llama` | llama.cpp inference on port 8080 |
| `ujust setup-inference-vllm` | vLLM inference on port 8000 |
| `ujust list-agents` | Show installed agent containers |

Inference engines are mutually exclusive (both fight for VRAM). Switching engines stops the other automatically.

```bash
# Start local inference with llama
ujust setup-inference-llama

# Switch to vLLM (stops llama first)
ujust setup-inference-vllm

# Switch quant on llama (Q4_K_M ↔ Q8_0)
ujust inference-model

# Use it in Hermes
hermes model set custom:local-llama/bottlecapai/ThinkingCap-Qwen3.6-27B-GGUF:Q4_K_M
```

The inference container has GPU access via `nvidia-container-toolkit` and runs as a systemd user service for persistence.

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
│  │  ├── recovery (Shift-at-boot root shell)         │  │
│  │  ├── ujust/chaossynergy.just                     │  │
│  │  │   (agents + inference recipes)                │  │
│  │  └── ADR-011/012 (local inference, toolchain)    │  │
│  └──────────────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Distrobox containers (on-demand via ujust)       │  │
│  │  ├── hermes    (first-boot, orchestration)       │  │
│  │  ├── opencode  (coding agent)                    │  │
│  │  ├── pi        (Pi coding agent)                 │  │
│  │  ├── claude    (Claude Code)                     │  │
│  │  └── inference (llama.cpp or vLLM)               │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```

## ADRs

Architecture Decision Records live in [`chaos_files/docs/adr/`](chaos_files/docs/adr/). Key records:

| # | Title | Status |
|---|-------|--------|
| ADR-001 | [Architecture Decisions](chaos_files/docs/adr/ADR-001-architecture-decisions.md) | Accepted |
| ADR-004 | [Multi-Agent Architecture](chaos_files/docs/adr/ADR-004-multi-agent-architecture.md) | Draft |
| ADR-005 | [Minimal Host, Container-First](chaos_files/docs/adr/ADR-005-minimal-host-container-first.md) | Draft |
| ADR-008 | [Desktop Experience](chaos_files/docs/adr/ADR-008-desktop-experience.md) | Accepted |
| ADR-010 | [Visual Context for Agent-Human Pairing](chaos_files/docs/adr/ADR-010-presence-aware-safety.md) | Proposed |
| ADR-011 | [Local Inference Runtime](chaos_files/docs/adr/ADR-011-local-inference-runtime.md) | Draft |
| ADR-012 | [Agent Toolchain Expansion](chaos_files/docs/adr/ADR-012-agent-toolchain-expansion.md) | Draft |

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