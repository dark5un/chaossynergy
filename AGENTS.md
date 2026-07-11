# Chaossynergy — Agent Instructions

This repo is a fork of `ublue-os/bluefin` with our overlay in `chaos_files/`.

## Key files

| File | Purpose |
|------|---------|
| `Containerfile` | Build definition — runs Bluefin's scripts then our `chaos_files/build.sh` |
| `chaos_files/build.sh` | Post-build overlay: herdr, services, branding |
| `chaos_files/system_files/` | Our configs (autostart, launcher, wallpaper, icon) |
| `chaos_files/disk_config/iso.toml` | Anaconda ISO branding |
| `chaos_files/docs/adr/` | Architecture Decision Records |

## Branch strategy

- `chaos` — default branch, our active image
- Rebase on `ublue-os/bluefin:main` to get upstream updates

## Build

```bash
sudo just build chaossynergy stable main
```