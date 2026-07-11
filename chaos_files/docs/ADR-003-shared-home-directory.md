# ADR-003: Shared Home Directory for Hermes Container

**Status:** Accepted
**Date:** 2026-07-10
**Author:** Panagiotis Xynos (Master) / OrsonRius (Padawan)

## Context

The Hermes agent runs inside a distrobox container. The container's home directory determines what files the agent can see and where it stores its state, configuration, and memory.

The initial prototype used a dedicated home at `/var/lib/hermes` — a separate directory owned by the container. This was chosen for isolation: the agent's state would be contained and disposable.

## Problem

A separate home directory creates confusion for the agent:

1. **Project context mismatch** — The user works in `~/workspace/`. The agent lives in `/var/lib/hermes/`. The agent cannot see the user's projects, git repos, or config files without explicit mounts or symlinks.

2. **Tooling confusion** — Tools like `gh`, `git`, and `ssh` store their config in `~/.config/` and `~/.ssh/`. With a separate home, the agent either lacks these credentials or needs them copied over — which means they get out of sync.

3. **Dual reality** — The agent thinks its "home" is one place, but the user's world is another. This leads to the agent writing files the user can't find, or reading configs that don't reflect reality.

4. **State fragmentation** — Hermes stores its memory, session history, and learned patterns in its home directory. With a separate home, this state is invisible to the user and survives or disappears independently of the user's actual work.

## Decision

Remove the `--home /var/lib/hermes` argument from the distrobox create command. The Hermes container inherits the user's home directory by default — same as any other distrobox container.

## Rationale

distrobox's default behavior is to share the user's home. This is the expected pattern for development containers — you enter a container and you're in the same directory with the same files.

By not overriding `--home`, we get:

- **Agent sees what the user sees** — same projects, same configs, same credentials
- **No sync needed** — `~/.ssh/`, `~/.config/gh/`, `~/.gitconfig` are all accessible
- **State is where the user expects it** — Hermes memory, agent state, generated files are in the user's home, not a hidden `/var/lib/` directory
- **Disposability is preserved** — `distrobox rm hermes` still removes the container. The user's files in the home survive because they're bind-mounted, not copied
- **Simplicity** — one fewer special path to configure, document, and troubleshoot

## Consequences

- Hermes gains access to the user's home directory — including SSH keys and git credentials. This is acceptable because the agent already has `--privileged` access and the user explicitly invited it.
- If the user wants to reset the agent's state (memory, config), they need to clean specific dotfiles in their home rather than deleting a directory. The setup script documents which paths to clean.
- The agent's home is no longer "disposable" in the sense that `rm -rf /var/lib/hermes` wipes it — but `distrobox rm hermes` still wipes the container itself cleanly.

## References

- [distrobox documentation](https://github.com/89luca89/distrobox)
- [ADR-001](ADR-001-architecture-decisions.md) — Architecture Decisions for the Chaossynergy Prototype
- [ADR-002](ADR-002-herdr-multiplexer.md) — herdr Terminal Multiplexer