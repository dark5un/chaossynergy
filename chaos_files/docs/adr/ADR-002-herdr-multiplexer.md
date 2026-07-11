# ADR-002: Replace tmux with herdr as the Terminal Multiplexer

**Status:** Accepted
**Date:** 2026-07-10
**Author:** Panagiotis Xynos (Master) / OrsonRius (Padawan)

## Context

The Chaossynergy prototype uses a terminal-based launcher as the primary user interface. The launcher needs to present the Hermes agent in a full-screen terminal, provide workspace management, and support recovery access.

The initial prototype used **tmux** for this purpose — a proven, battle-tested terminal multiplexer. However, tmux is a general-purpose tool designed for human terminal users. It has no concept of "agents" — it treats every pane as an opaque shell.

## Decision

Replace tmux with **herdr** ([github.com/fabiorizzomatos/herdr](https://github.com/fabiorizzomatos/herdr)) as the terminal multiplexer in the Chaossynergy launcher.

herdr is a Rust-based terminal-native agent multiplexer purpose-built for AI coding agents. It provides:

- **Agent awareness** — automatically detects running agents (Claude Code, Codex, OpenCode, etc.) and shows their state: blocked, working, done, idle
- **Workspace model** — each project gets its own workspace with tiled panes
- **Notification system** — sidebar shows workspace-level and agent-level state, with optional sound/toast notifications
- **Socket API** — agents can programmatically create workspaces, split panes, send input, read output, and wait for state
- **Agent Skill** — SKILL.md provides a reusable workflow for agents operating inside herdr
- **Mouse support** — click to focus, drag to resize, no keyboard-only limitation

## Alternatives Considered

### tmux (used in initial prototype)

**Pros:**
- Ubiquitous, proven, stable
- Everyone knows the keybindings
- Scriptable via `send-keys`

**Cons:**
- No agent awareness — every pane is an opaque shell
- No workspace-level state aggregation
- Screen-scraping for output capture is fragile
- No native agent integration API

### RMUX ([rmux.io](https://rmux.io))

**Pros:**
- tmux-compatible (same 90 commands, same keybindings)
- Typed SDKs (Rust, Python, TypeScript)
- Claude Teammate Mode built in
- Cross-platform (Linux, macOS, Windows)

**Cons:**
- Younger project, smaller community
- No agent state detection (blocked/working/done)
- Focused on being a tmux replacement, not an agent multiplexer

### HOM ([github.com/mudrii/hom](https://github.com/mudrii/hom))

**Pros:**
- Full TUI with real terminal emulators in panes
- YAML workflow engine (DAG execution)
- Web UI for remote access
- MCP server for external chaossynergytion

**Cons:**
- Heaviest option (10-crate Rust workspace)
- Overkill for a launcher that primarily runs one agent
- More complex configuration

## Rationale

herdr aligns with Chaossynergy's philosophy:

- **Agent-first** — herdr is built for agents, not just humans. Its socket API lets agents control the multiplexer themselves, which is exactly what Chaossynergy's long-term vision requires.
- **State awareness** — herdr detects agent state automatically. This frees the Chaossynergy launcher from implementing its own agent detection and status display.
- **Lightweight** — single Rust binary, no external dependencies
- **Workspace model** — matches Chaossynergy's project-first pattern (one workspace per project)
- **Built with agents** — herdr was itself built by AI coding agents. Using it is a statement about the direction we're heading.

## Consequences

**Positive:**
- Agent-aware launcher out of the box
- Future agents can use herdr's socket API to chaossynergyte panes programmatically
- Sidebar provides at-a-glance status of all running agents
- Workspace model maps naturally to project-first UX

**Negative:**
- herdr is newer and less battle-tested than tmux
- No persistent session detach/reattach (planned but not yet implemented)
- Installation requires network access (curl to herdr.dev)
- AGPL-3.0 license (vs Apache-2.0 for the rest of Chaossynergy)
- Users familiar with tmux need to learn new keybindings

**Migration:**
- tmux remains installed in the image as a fallback
- The launcher script (`/usr/bin/chaossynergy`) now starts herdr instead of tmux
- Users can still run `tmux` manually if needed
- Recovery mode (Shift at boot) is unaffected — it runs before the launcher

## References

- [herdr repository](https://github.com/fabiorizzomatos/herdr)
- [herdr.dev](https://herdr.dev)
- [herdr SKILL.md](https://github.com/fabiorizzomatos/herdr/blob/main/SKILL.md)
- [herdr SOCKET_API.md](https://github.com/fabiorizzomatos/herdr/blob/main/SOCKET_API.md)
- [ADR-001](ADR-001-architecture-decisions.md) — Architecture Decisions for the Chaossynergy Prototype