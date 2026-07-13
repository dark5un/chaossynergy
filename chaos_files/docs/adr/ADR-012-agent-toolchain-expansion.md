# ADR-012: Agent Toolchain Expansion

**Status:** Draft — design direction, not yet implemented
**Date:** 2026-07-13
**Author:** Panagiotis Xynos (Master) / OrsonRius (Padawan)

## Context

Chaossynergy currently ships with a single agent — Hermes — running in its own distrobox container, started at first boot by `setup-hermes.service`. Herdr provides the terminal multiplexer layer.

ADR-004 established the architectural pattern for running multiple agents in isolated distrobox containers. The motivation was clear from the start: different tools are good at different things. Hermes is the orchestrator and infrastructure agent. Coding tasks benefit from specialized coding agents that understand project structure, run tests, and iterate on codebases.

Three additional agents are now ready for integration:

1. **OpenCode** — Provider-agnostic, open-source coding agent with TUI and CLI. Good for feature implementation, refactoring, and code review. Already has a Hermes skill for orchestration. npm-installable.

2. **Pi (Coding Agent)** — A minimalist, extensible coding agent harness by Earendil Inc. (`@earendil-works/pi-coding-agent` on npm). Designed to be self-modifying — ask Pi to build an extension for its own capabilities. Tree-structured session history, four modes (interactive, print/JSON, RPC, SDK), 15+ provider support. npm-installable.

3. **Claude Code** — Anthropic's official coding agent. Terminal-first with TUI. Available as an npm package (`@anthropic-ai/claude-code`). Strong integration with Claude models.

Each agent has different strengths and design philosophies. Rather than choosing one, Chaossynergy makes them all available and lets the user (and orchestrating agent) pick the right tool for the job.

## Decision 1: Three Coding Agents, One Pattern

**Decision:** Install OpenCode, Pi, and Claude Code as optional coding agents, each in their own distrobox container following the `setup-agent@.service` template from ADR-004.

| Agent | Package | Language | Philosophy | Best For |
|-------|---------|----------|-----------|----------|
| **Hermes** | Hermes Agent | Python | All-purpose assistant, tool-wielding orchestrator | Infrastructure, OS build, multi-step orchestration |
| **OpenCode** | `opencode-ai` (npm) | TypeScript | Provider-agnostic, standards-compliant | Feature work, PR review, test-driven development |
| **Pi** | `@earendil-works/pi-coding-agent` (npm) | TypeScript | Minimal harness, extensible, self-modifying | Custom workflows, extensions, context engineering |
| **Claude Code** | `@anthropic-ai/claude-code` (npm) | TypeScript | Anthropic-native, deep Sonnet integration | Complex coding tasks, research-grade reasoning |

**Alternatives considered:**

| Alternative | Rationale |
|-------------|-----------|
| **Single agent to rule them all** | No agent excels at everything. Hermes is a generalist orchestrator, not a specialized coder. |
| **Only OpenCode** | OpenCode is open-source and provider-agnostic, which aligns with Chaossynergy's philosophy. But Pi's extension model and Claude Code's Sonnet integration cover different use cases. |
| **Only Claude Code** | Most capable model-wise, but requires Anthropic API key, vendor lock-in, and is less extensible than Pi. |
| **Only Pi** | Most extensible and self-modifying, but newer ecosystem and fewer integrations than OpenCode. |
| **Install all in one container** | Cross-contamination of configs, conflicts between TypeScript versions, different provider auth. |

**Rationale:**

- Each agent has a genuinely different design philosophy. Having all three lets us evaluate which fits best for which task, and the user can form their own preference.
- They share no runtime dependencies (all TypeScript/npm) so installation is trivial and consistent.
- Per ADR-004, each agent in its own distrobox means zero config conflicts.
- The "one chokepoint" principle (ADR-004) applies — all agent-to-agent communication passes through herdr, which is observable and controllable.
- The disk overhead is negligible: each container is the base Fedora image (~200 MB) + npm packages (~100 MB each).

## Decision 2: Hermes as Orchestrator

**Decision:** Hermes remains the primary orchestrator. Coding agents are spawned on demand by Hermes via herdr's socket API.

**Workflow:**

1. User presents a task to Hermes (e.g., "Implement OAuth refresh flow")
2. Hermes analyzes the task and decides which coding agent to delegate to
3. Hermes opens a new herdr pane with the chosen agent, passing context via stdin or a file
4. The coding agent works on the task, Hermes monitors progress via herdr's socket API
5. When the agent finishes, Hermes reviews the result, runs tests, and reports back
6. All intermediate state is visible in herdr's session tree

**Routing heuristics (Hermes decides):**

| Task Type | Preferred Agent | Reason |
|-----------|----------------|--------|
| Feature implementation | OpenCode | Provider-agnostic, strong tool use |
| PR review / code inspection | OpenCode or Claude Code | Built-in PR review commands |
| Custom workflow / extension | Pi | Self-modifying, extensible, "build what you need" |
| Research / complex logic | Claude Code | Deep Sonnet reasoning, large context |
| OS build / infrastructure | Hermes itself | Owns the Containerfile, systemd, CI |

These are heuristics, not rules. The user can override with `use opencode` or `use pi`.

## Decision 3: ujust-Driven Installation

**Decision:** Coding agents are installed on demand via `ujust` recipes, not via systemd boot services. Hermes itself keeps its first-boot systemd service (the OS needs its primary agent to be ready from boot). Everything else is user-initiated.

The division is simple:

| Agent | Install Mechanism | Why |
|-------|------------------|-----|
| **Hermes** | `setup-hermes.service` (systemd, first-boot) | Primary agent, OS needs it |
| **Inference** | `ujust setup-inference` | 16-22 GB model download, user decides when |
| **OpenCode** | `ujust setup-opencode` | Optional coding tool |
| **Pi** | `ujust setup-pi` | Optional coding tool |
| **Claude Code** | `ujust setup-claude` | Optional coding tool |

This applies ADR-005's "minimal host" principle to the agent layer too — nothing runs until the user asks for it. Herdr doesn't care what agents exist or how they were installed; it just multiplexes whatever harness is running in a pane.

**Alternatives considered:**

| Alternative | Rationale for rejecting |
|-------------|------------------------|
| **systemd template `setup-agent@.service`** (previous decision) | Requires sudo, runs at boot, user has no say in timing. Over-engineered for optional agents. |
| **Pre-baked into OS image** | Bloats the image, contradicts ADR-005. Agents update independently of the OS. |
| **Hermes auto-spawns them** | Hermes would need to manage podman/distrobox lifecycle — scope creep. Hermes delegates *tasks*, not *installs*. |

## Decision 4: Lazy Installation — On-Demand Only

**Decision:** Coding agents are created on first `ujust setup-<name>` invocation, not on first boot.

**Implementation:**

The `chaossynergy.just` file (shipped at `/usr/share/chaossynergy/just/`) includes:

```make
# ── Coding agent setup ─────────────────────────────────
setup-opencode:
    @test -n "$(distrobox list | grep opencode)" && echo "OpenCode agent already exists" && exit 0
    echo "Creating OpenCode distrobox..."
    distrobox create --name opencode --image quay.io/fedora/fedora:latest
    distrobox enter opencode -- npm install -g opencode-ai@latest
    distrobox enter opencode -- opencode auth list 2>/dev/null || echo "Run 'ujust setup-opencode-auth' to configure providers"
    echo "OpenCode ready. Enter with: distrobox enter opencode"

setup-opencode-auth:
    distrobox enter opencode -- opencode auth login

setup-pi:
    @test -n "$(distrobox list | grep pi)" && echo "Pi agent already exists" && exit 0
    echo "Creating Pi distrobox..."
    distrobox create --name pi --image quay.io/fedora/fedora:latest
    distrobox enter pi -- npm install -g @earendil-works/pi-coding-agent
    echo "Pi agent ready. Enter with: distrobox enter pi"

setup-claude:
    @test -n "$(distrobox list | grep claude)" && echo "Claude Code agent already exists" && exit 0
    echo "Creating Claude Code distrobox..."
    distrobox create --name claude --image quay.io/fedora/fedora:latest
    distrobox enter claude -- npm install -g @anthropic-ai/claude-code
    echo "Claude Code ready. Enter with: distrobox enter claude"

setup-all-agents: setup-opencode setup-pi setup-claude
    echo "All coding agents installed"

list-agents:
    @echo "Available agent containers:"
    distrobox list | grep -E "^(hermes|opencode|pi|claude|inference)" || echo "No Chaossynergy agents found"
    @echo ""
    @echo "Run 'ujust setup-<name>' to install missing agents"

remove-agent:
    @read -p "Agent name to remove (opencode/pi/claude): " name
    distrobox rm "$$name" 2>/dev/null && echo "Removed $$name" || echo "Agent not found"
```

**Hermes integration:**

When Hermes decides to delegate to a coding agent that isn't installed, it prompts the user:

```
I need OpenCode for this task, but it's not installed yet.
Run this in your terminal: ujust setup-opencode
Then I can proceed with the delegation.
```

This keeps Hermes focused on orchestration, not infra management.

## Rollout Plan

| Phase | What | 
|-------|------|
| **Phase 1** | Create `chaossynergy.just` with `setup-opencode`, `setup-pi`, `setup-claude`, `list-agents`, `remove-agent` recipes |
| **Phase 2** | Add herdr socket API for agent-to-agent communication |
| **Phase 3** | Test each agent independently — create container, enter, run a task |
| **Phase 4** | Implement Hermes delegation heuristics (tool routing) with ujust prompt for missing agents |
| **Phase 5** | Pi extension development — build custom workflows for Chaossynergy |

## Consequences

**Positive:**

- Users have a choice of specialized coding agents without installing anything extra
- Each agent is isolated, independently resettable, and independently upgradeable
- Hermes acts as an orchestrator, not a jack-of-all-trades — it delegates to specialists
- The pattern is extensible — adding a new agent means adding a 10-line `just` recipe
- Lazy installation via `ujust` means zero first-boot overhead and user-controlled timing
- Pi's extensibility means users can build custom Chaossynergy extensions (e.g., a "build and deploy" workflow)
- `ujust list-agents` gives an at-a-glance view of what's available
- No sudo required for agent installation — `ujust` runs as the user, distrobox handles the rest
- Herdr remains agnostic — it doesn't care what pane contains which harness

**Risks:**

- npm packages for three coding agents + their transitive dependencies consume ~300-500 MB per container
- TypeScript runtime is shared but each agent may pin different Node.js versions
- Three agents means three API keys to manage (if using different providers)
- Agent proliferation could confuse new users — too many choices
- Claude Code requires an Anthropic API key; OpenCode and Pi work with any provider
- herdr socket API is still evolving — agent orchestration patterns may change
- If a coding agent makes changes to the filesystem that Hermes doesn't expect, state can diverge

## Agent Comparison Matrix

| Feature | OpenCode | Pi | Claude Code |
|---------|----------|----|-------------|
| **Open source** | Yes (MIT) | Yes (MIT) | No (source available) |
| **Provider-agnostic** | Yes | Yes | Claude-only |
| **Install** | `npm i -g opencode-ai` | `npm i -g @earendil-works/pi-coding-agent` | `npm i -g @anthropic-ai/claude-code` |
| **Extension system** | No (config-driven) | Yes (TypeScript modules, 50+ examples) | No (config-driven) |
| **MCP support** | Built-in | Via extension | Built-in |
| **Session history** | File-based | Tree-structured, shareable | File-based |
| **Self-modifying** | No | Yes ("ask Pi to build it") | No |
| **PR review** | `opencode pr N` | Via extension | `claude pr N` |
| **Background mode** | Via herdr (this ADR) | Via herdr (this ADR) | Via herdr (this ADR) |
| **Plan mode** | No | Via extension | Yes (`claude think`) |
| **Context engineering** | AGENTS.md | AGENTS.md, SYSTEM.md, compaction, skills | CLAUDE.md |

## References

- [ADR-004](ADR-004-multi-agent-architecture.md) — Multi-agent architecture with herdr + distrobox
- [ADR-011](ADR-011-local-inference-runtime.md) — Local inference runtime
- [OpenCode](https://opencode.ai) — Open-source coding agent
- [Pi Agent](https://pi.dev) — Minimal coding agent harness (Earendil Inc.)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview) — Anthropic's coding agent
- [herdr SOCKET_API.md](https://github.com/ogulcancelik/herdr/blob/main/SOCKET_API.md) — herdr socket API