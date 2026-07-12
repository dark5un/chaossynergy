# ADR-007: Secrets Management with pass

**Status:** Accepted
**Date:** 2026-07-11
**Author:** Panagiotis Xynos (Master) / OrsonRius (Padawan)

## Context

Hermes Agent needs API keys for its providers (OpenRouter, Anthropic, OpenAI, etc.). Chromium needs passwords for web services. Both need to access and manage these secrets securely.

The keys should be:
1. **Encrypted at rest** — not stored in plaintext config files
2. **Accessible to both Hermes and Chromium** — single source of truth
3. **Local-first** — no cloud dependency for secret storage
4. **Portable** — the store is a directory, easily backed up or synced

## Decision

Use `pass` (the standard Unix password store) as the secrets backend, with `browserpass` providing Chromium access.

### How it works

1. The user generates a GPG key (or imports an existing one)
2. `pass init <key-id>` creates `~/.password-store/`
3. Secrets are stored as GPG-encrypted files:

```
~/.password-store/
├── hermes/
│   ├── openrouter.gpg        # pass show hermes/openrouter
│   ├── anthropic.gpg         # pass show hermes/anthropic
│   └── github-token.gpg      # pass show hermes/github-token
├── websites/
│   ├── github.com.gpg        # Browserpass fills this
│   └── google.com.gpg
└── .gpg-id                   # The key fingerprint
```

4. Hermes reads from pass directly: `pass show hermes/openrouter`
5. Chromium reads via browserpass: Chrome extension → browserpass-native → pass

### First-boot setup

`user-setup.sh` detects if `~/.password-store/.gpg-id` exists. If not, it prints instructions for:
1. `gpg --full-generate-key` — create a GPG key
2. `pass init <key-id>` — initialize the store

### Hermes integration

The user creates entries with `pass insert hermes/<provider>`. Hermes is configured to read these via the `pass` CLI in a profile or config hook. This replaces storing API keys in `~/.hermes/.env`.

## Alternatives considered

- **`~/.hermes/.env`** — Current approach, plaintext. Convenient but unencrypted. Fine for development, not for a shipped OS.
- **`gnome-keyring` / `libsecret`** — Tightly coupled to GNOME. Not easily accessible from Hermes in the terminal.
- **`systemd-credentials`** — Designed for system services, not user sessions.
- **Bitwarden CLI** — Cloud-dependent, requires daemon (`bw serve`). Adds attack surface.
- **`pass` (chosen)** — Minimal, Unix-native, GPG-encrypted, no daemon, works offline.

## Rationale

- GPG is already available on every Linux system
- `pass` stores each secret as a separate file — easy to backup, sync, or version-control (encrypted)
- `browserpass` provides the same `pass` store to Chromium
- No daemon process — secrets are decrypted on-demand with a single GPG operation
- Syncs trivially with `git` (pass has built-in git support: `pass git init && pass git push`)
- Works identically inside and outside the distrobox container (shared home)

## Consequences

- GPG key management is user responsibility — lost key = lost secrets
- The user must run `pass insert` for each API key (one-time step)
- `~/.password-store` is GPG-encrypted but accessible to any process running as the user — standard Linux security model
- browserpass needs the native messaging host manifest registered — handled in the Containerfile
- pass `git` integration means secrets can be synced across machines (user's choice)

## References

- [pass: The Standard Unix Password Manager](https://www.passwordstore.org/)
- [browserpass](https://github.com/browserpass/browserpass-extension)
- [browserpass-native](https://github.com/browserpass/browserpass-native)
- [GPG Manual](https://gnupg.org/documentation/manuals/gnupg/)
- [ADR-006](ADR-006-browser-mcp-integration.md) — Browser and MCP integration
