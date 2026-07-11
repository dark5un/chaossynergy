# ADR-004: Multi-Agent Architecture with herdr + Distrobox

**Status:** Draft — design direction, not yet implemented
**Date:** 2026-07-10
**Author:** Panagiotis Xynos (Master) / OrsonRius (Padawan)

## Context

Chaossynergy launches Hermes in a distrobox container as its primary agent. herdr provides the terminal multiplexer layer with agent-aware state detection (blocked/working/done/idle).

herdr's design — workspaces, panes, socket API, agent detection — naturally supports running multiple agents simultaneously. Each agent could be an independent process with its own context, tools, and state.

This ADR captures the design for extending Chaossynergy to support multiple agents, each in their own distrobox, chaossynergyted through herdr.

## Proposed Architecture

```
herdr (terminal multiplexer, agent-aware sidebar)
├── Workspace: "local-cloud"
│   ├── Pane 1: Hermes (distrobox: hermes)
│   │   └── Infrastructure agent — OpenTofu, Dagger, k8s
│   ├── Pane 2: Claude Code (distrobox: claude)
│   │   └── Implementation agent — feature work
│   └── Pane 3: Codex (distrobox: codex)
│       └── Review agent — PR review, tests
└── Workspace: "chaossynergy"
    └── Pane 1: Hermes (distrobox: hermes)
        └── OS build agent — Containerfile, systemd, CI
```

Each agent is:
- **Isolated** — own distrobox container, own home bind-mount, own toolchain
- **Stateful** — each container has its own home directory (or shares the user's home with its own config namespace)
- **Detectable** — herdr identifies the foreground process and reads terminal output for state
- **Chaossynergyble** — agents can use herdr's socket API to create panes, spawn other agents, read output, wait on state

## Why Distrobox per Agent

| Alternative | Pros | Cons |
|-------------|------|------|
| **Single container, multiple shells** | Simple, less overhead | Agents share state, tools, config — cross-contamination risk |
| **Distrobox per agent** (chosen) | Full isolation, separate toolchains, independent reset | More disk space (~1-2 GB per container) |
| **Podman containers directly** | Lightest | No distrobox integration (home sharing, tool export) |
| **Host-native** | Zero isolation overhead | Pollutes host, contradicts "sacred host" principle |

Distrobox per agent gives us:
- `distrobox rm <name>` to reset any agent independently
- Each agent can have a different base image (Hermes container vs Claude Code container vs raw Fedora)
- herdr detects each agent independently via its foreground process
- No cross-contamination of configs, credentials, or installed tools

## Distribution Method

A systemd template service `setup-agent@.service` can create any named agent container:

```bash
systemctl start setup-agent@hermes.service
systemctl start setup-agent@claude.service
systemctl start setup-agent@codex.service
```

Each agent gets its own distrobox with:
- Shared home (per ADR-003)
- An `agent-start` script that launches the appropriate CLI tool
- herdr detects it automatically

## Agent Interaction via herdr Socket API

herdr's socket API enables agents to cooperate:

1. Hermes (infrastructure) creates a workspace and spawns Claude Code in a sibling pane
2. Hermes delegates a task: "implement this OpenTofu module"
3. Hermes reads Claude Code's output via herdr's socket
4. When Claude Code finishes (herdr detects "done" state), Hermes reviews the result

This is the **one chokepoint** principle in action — all agent-to-agent communication passes through herdr, which is observable and controllable.

## Rollout Plan

| Phase | What | 
|-------|------|
| **Prototype (current)** | Hermes only, single distrobox, tmux or herdr |
| **Phase 3** | Hermes in herdr, document multi-agent patterns |
| **Phase 4** | systemd template `setup-agent@.service` for additional agents |
| **Phase 5** | herdr socket API integration — agents spawning agents |
| **Phase 6** | Project profiles — "local-cloud workspace" automatically spawns Hermes + OpenTofu tooling |

## Consequences

**Positive:**
- Scale from 1 to N agents without architectural changes
- Each agent is independently resettable
- herdr sideboard gives at-a-glance status across all agents
- Socket API enables sophisticated chaossynergytion patterns
- The "one chokepoint" principle is realized through herdr

**Risks:**
- Multiple privileged distrobox containers expand the attack surface
- Resource usage grows with each additional agent (RAM, disk)
- herdr socket API is still evolving — may change
- Agent-to-agent communication patterns are unproven

## References

- [herdr SOCKET_API.md](https://github.com/fabiorizzomatos/herdr/blob/main/SOCKET_API.md)
- [herdr SKILL.md](https://github.com/fabiorizzomatos/herdr/blob/main/SKILL.md)
- [ADR-002](ADR-002-herdr-multiplexer.md) — herdr Terminal Multiplexer
- [ADR-003](ADR-003-shared-home-directory.md) — Shared Home Directory
- [ADR-001](ADR-001-architecture-decisions.md) — Architecture Decisions