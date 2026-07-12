# Chaossynergy — Agent Instructions

Built on Bluefin LTS (CentOS Stream 10). Single Containerfile with our overlay.

## Build

```bash
just build-chaossynergy stable

# Then QCOW2 for VM testing
just build-qcow2 stable
just run-vm-qcow2 stable
```

## Key files

| File | Purpose |
|------|---------|
| `Containerfile` | `FROM bluefin-lts:stable` + our `chaos_files/` overlay |
| `chaos_files/build.sh` | Post-build: herdr, branding, services |
| `chaos_files/system_files/` | Our configs (autostart, wallpaper, icon) |
| `chaos_files/docs/adr/` | Architecture Decision Records |

## Architecture

```
┌────────────────────────────────────────────────────────┐
│  Bluefin LTS (CentOS Stream 10, GNOME 49)              │
│  ┌──────────────────────────────────────────────────┐  │
│  │  Chaossynergy overlay                             │  │
│  │  ├── herdr (fullscreen terminal on boot)         │  │
│  │  ├── user-setup (first login automation)         │  │
│  │  ├── branding (wallpaper, icon)                  │  │
│  │  └── recovery (Shift-at-boot root shell)         │  │
│  └──────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────┘
```