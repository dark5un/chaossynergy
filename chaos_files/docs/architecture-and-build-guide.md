# Chaossynergy — Architecture & Build Guide

> **The Philosophical Developer**
> *How and why we build an agent-native operating system*

---

## 1. The Ecosystem Explained

This section explains every technology Chaossynergy touches, from the bottom up. If you're new to bootc, Universal Blue, or immutable Linux, start here.

### 1.1 bootc — Bootable Containers

**What it is:** [bootc](https://github.com/bootc-dev/bootc) is a CNCF sandbox project that lets you use standard OCI container images (like Docker images) as bootable operating systems. Instead of `apt upgrade` or `dnf update`, you `bootc switch` to a new container image. Updates are atomic and rollback-able.

**How it works:**
1. You build a container image with a Linux kernel, initramfs, and userspace
2. You deploy it with `bootc switch ghcr.io/yourname/image:tag`
3. On next reboot, bootc extracts the container layers, generates a bootloader entry, and boots into the new OS
4. The previous deployment is preserved — hold Shift at boot to roll back

**Key insight:** bootc is not a distribution. It's a client tool that runs on distro-maintained base images (Fedora, CentOS, Universal Blue). The [bootc docs](https://bootc.dev/bootc/building/guidance.html) explicitly say base images should be owned by OS vendors, not by end users.

### 1.2 Universal Blue — The Distribution Layer

**What it is:** [Universal Blue](https://universal-blue.org/) (uBlue) is a community that builds production-grade bootc base images on top of Fedora Atomic/CentOS. They are the main reason bootc is usable today — they do the hard work of kernel management, driver integration, firmware updates, and desktop configuration.

**The image hierarchy:**
```
quay.io/fedora-ostree-desktops/base-atomic     ← Fedora upstream, raw
        ↓
ghcr.io/ublue-os/base-main                     ← uBlue base (no desktop)
ghcr.io/ublue-os/silverblue-main               ← uBlue base + GNOME
ghcr.io/ublue-os/kinoite-main                  ← uBlue base + KDE
        ↓
ghcr.io/ublue-os/bluefin:stable               ← Bluefin (GNOME desktop)
ghcr.io/ublue-os/bazzite:stable               ← Bazzite (gaming + KDE/GNOME)
ghcr.io/ublue-os/aurora:stable                ← Aurora (KDE desktop)
        ↓
ghcr.io/ublue-os/bluefin-dx:stable            ← Bluefin DX (dev tools)
ghcr.io/ublue-os/bluefin-dx-nvidia:stable     ← Bluefin DX + NVIDIA drivers
        ↓
ghcr.io/dark5un/chaossynergy:latest              ← Chaossynergy (our image)
```

Each layer adds opinion — Fedora gives you the kernel, uBlue gives you GNOME, Bluefin gives you developer defaults, Bluefin DX adds dev tools, Chaossynergy adds the agent.

### 1.3 Bluefin DX NVIDIA — Our Base Image

**Why this image specifically:**

| Component | What it gives us |
|-----------|-----------------|
| **Bluefin** | GNOME desktop, ujust commands, Bazaar app store, container-first workflow |
| **DX** | Docker, podman, distrobox, Homebrew, VSCode, dev tooling pre-installed |
| **NVIDIA** | NVIDIA drivers, CUDA, akmods, GPU acceleration — no manual setup |

**What we don't use (and why that's fine):**
- GNOME desktop → We boot into a TUI launcher, but GNOME is there as a fallback (Ctrl+B d to detach)
- Bazaar app store → Unused in TUI mode, but doesn't hurt
- Gaming packages → Inherited from Bluefin, inactive when not needed

### 1.4 The Image Template

Chaossynergy started from the [Universal Blue image-template](https://github.com/ublue-os/image-template). This template provides:

| File | Purpose |
|------|---------|
| `Containerfile` | Dockerfile-like build definition |
| `build_files/build.sh` | Script executed during build — installs packages, enables services |
| `system_files/` | Files copied into the image (systemd units, launcher scripts, configs) |
| `Justfile` | Local development commands (`just build`, `just build-qcow2`) |
| `.github/workflows/build.yml` | CI: builds OCI image, signs with cosign, pushes to GHCR |
| `.github/workflows/build-disk.yml` | CI: converts OCI image to bootable disk images (qcow2, ISO) |
| `cosign.pub` | Public key for verifying image signatures |
| `disk_config/` | Configuration for `bootc-image-builder` (disk size, filesystem) |

### 1.5 finpilot — The Alternative We Didn't Choose

[finpilot](https://github.com/projectbluefin/finpilot) is Bluefin's newer (2025+) template that uses multi-stage OCI assembly instead of `FROM bluefin:stable`. Instead of modifying Bluefin, you *assemble your own Bluefin* from shared OCI components.

**Why we didn't use it for the prototype:**
1. The current template (image-template) works and is proven across all example repos (bOS, m2OS, Amy OS, VeneOS)
2. Migrating to finpilot means reworking Containerfile, CI, and understanding OCI assembly — before we've even booted the prototype
3. YAGNI — the multi-stage pattern is a maintenance optimization, not a blocker
4. We can migrate in a later phase once the prototype is validated

### 1.6 bootc-image-builder — Disk Images

[bootc-image-builder](https://github.com/osbuild/bootc-image-builder) (recently merged into `osbuild/image-builder`) converts a bootc container image into bootable disk images:

| Type | Output | Use Case |
|------|--------|----------|
| `qcow2` | QEMU/KVM disk | VM testing (fastest iteration) |
| `bootc-installer` | Anaconda ISO | Installer that installs the container image |
| `anaconda-iso` | Anaconda ISO | Legacy installer (built from RPMs) |
| `raw` | Raw disk image | Direct dd to disk |
| `ami` | AWS AMI | Cloud deployment |

**How it works:** It runs as a privileged container that has access to your host's podman storage (to find the container image) and uses `--type qcow2` (or `iso`) to produce a disk image in an output directory. We trigger this via GitHub Actions (build-disk.yml) or locally with `sudo podman run ...`.

---

## 2. Architecture Decisions

### ADR-001: Base Image Choice

**Decision:** `ghcr.io/ublue-os/bluefin-dx-nvidia:stable`

**Rationale:**
- Pre-installed: podman, distrobox, Homebrew, Docker, dev toolchain
- Pre-baked NVIDIA drivers (CUDA, akmods) — no manual driver install
- Matches our daily-driver environment (Panos runs Bluefin)
- DX variant saves us from installing development tools ourselves

**Trade-offs:**
- Image is ~4-5 GB vs ~3 GB for plain bluefin
- Carries GNOME desktop, gaming packages, and other components we don't use
- Longer CI build times

### ADR-002: Build System

**Decision:** Image-template (not finpilot) for prototype

**Rationale:**
- Proven across all example repos
- CI pipeline works and is tested
- Migration to finpilot can happen later

### ADR-003: Hermes Provisioning

**Decision:** First-boot systemd service (not pre-baked)

**Rationale:**
- Host image stays small and clean
- Agent container is independently updatable
- `distrobox rm hermes && sudo systemctl start setup-hermes` resets the agent
- Disposable agent, sacred host

### ADR-004: User Interface

**Decision:** Terminal-first (TUI) for prototype

**Rationale:**
- Fast to build (~100 lines of bash)
- Validates the concept before graphical UI investment
- GNOME still available as fallback (Ctrl+B d or boot without launcher)

### ADR-005: Repository

**Decision:** GitHub (`github.com/dark5un/chaossynergy`)

**Rationale:**
- GitHub Actions for CI/CD
- GHCR for container image registry
- Already set up from the original repo

---

## 3. Build Pipeline — End to End

### 3.1 Local Build (container only)

```bash
# Inside Hermes distrobox (non-sudo, via host podman)
distrobox-host-exec podman build --pull=newer \
  --tag localhost/chaossynergy:verify \
  -f Containerfile .

# Bootc lint
distrobox-host-exec podman run --rm \
  localhost/chaossynergy:verify bootc container lint
```

**What happens:**
1. `Containerfile` is processed:
   - Stage 1: `FROM scratch` as `ctx`, copies `build_files/`
   - Stage 2: `FROM bluefin-dx-nvidia:stable`, copies `system_files/`, runs `build.sh`, runs `bootc container lint`
2. `build.sh` installs packages (python3-virtualenv, tmux) and enables systemd services
3. `bootc container lint` validates the image structure (11 checks)
4. Image is tagged `localhost/chaossynergy:verify`

### 3.2 Local Build (disk image)

Requires sudo on the host (for `--privileged` bootc-image-builder):

```bash
cd ~/workspace/chaossynergy
sudo podman build --pull=newer -t localhost/chaossynergy:verify -f Containerfile .
sudo podman run --rm -it --privileged --pull=newer \
  --security-opt label=type:unconfined_t \
  -v "$(pwd)/disk_config/disk.toml:/config.toml:ro" \
  -v "$(pwd)/output:/output" \
  -v /var/lib/containers/storage:/var/lib/containers/storage \
  quay.io/centos-bootc/bootc-image-builder:latest \
  --type qcow2 --use-librepo=True --rootfs btrfs \
  localhost/chaossynergy:verify
```

Output: `output/qcow2/disk.qcow2`

### 3.3 CI Pipeline (GitHub Actions)

The real builds happen on GitHub Actions. Two workflows:

**build.yml** — Triggered on push to main, daily schedule, or manual:
1. Checkout repo
2. Maximize build space (GitHub runners fill up)
3. Build OCI image with buildah
4. Push to `ghcr.io/dark5un/chaossynergy:latest` (and date-stamped tags)
5. Sign with cosign (key: `SIGNING_SECRET` secret, `cosign.pub` in repo)
6. Generate SBOM

**build-disk.yml** — Manual trigger (`gh workflow run "Build disk images"`):
1. Pull the OCI image from GHCR
2. Run bootc-image-builder to produce qcow2 + anaconda-iso
3. Upload artifacts (available for 90 days)
4. Optionally upload to S3

### 3.4 Deployment

```bash
# Switch to the image
sudo bootc switch --enforce-container-sigpolicy \
  ghcr.io/dark5un/chaossynergy:latest

# Reboot into Chaossynergy
sudo systemctl reboot
```

On first boot:
1. `chaossynergy-recovery.service` runs — hold Shift for root shell
2. `setup-hermes.service` runs (only on first boot) — pulls Hermes container, creates distrobox
3. `chaossynergy-launcher.service` starts — tmux with Hermes in main pane
4. You're in the agent

---

## 4. Repository Structure

```
chaossynergy/
├── Containerfile                          # Image build definition
├── Justfile                               # Local dev commands
├── README.md                              # This repo's README
├── build_files/
│   └── build.sh                           # Build-time script (packages, services)
├── system_files/
│   └── usr/
│       ├── bin/
│       │   └── chaossynergy                  # TUI launcher binary
│       └── lib/
│           ├── systemd/system/
│           │   ├── setup-hermes.service   # First-boot Hermes container setup
│           │   ├── chaossynergy-launcher.service  # TUI launcher auto-start
│           │   └── chaossynergy-recovery.service  # Shift-at-boot recovery
│           └── hermes/
│               ├── setup-container.sh     # Pulls Hermes, creates distrobox
│               └── recovery-check.sh      # 3-second Shift key detection
├── disk_config/
│   ├── disk.toml                          # QCOW2 disk config (20 GiB root)
│   └── iso.toml                           # ISO installer config
├── docs/
│   ├── bootc-template-guide.md            # Original template instructions
│   └── adr/
│       └── ADR-001-architecture-decisions.md  # Architecture decisions
├── .github/
│   ├── workflows/
│   │   ├── build.yml                      # OCI image CI
│   │   └── build-disk.yml                 # Disk image CI
│   ├── dependabot.yml
│   └── renovate.json5
├── cosign.pub                             # Signing public key
└── artifacthub-repo.yml                   # ArtifactHub registry metadata
```

---

## 5. Service Architecture at Runtime

```
┌──────────────────────────────────────────────────┐
│  bootc host (bluefin-dx-nvidia)                  │
│  ┌────────────────────────────────────────────┐  │
│  │  First boot only:                          │  │
│  │  setup-hermes.service                      │  │
│  │  └─ Pulls ghcr.io/nousresearch/hermes      │  │
│  │  └─ Creates distrobox "hermes"             │  │
│  │  └─ Home: /var/lib/hermes                  │  │
│  └────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────┐  │
│  │  Every boot:                                │  │
│  │  chaossynergy-recovery.service                 │  │
│  │  └─ Displays "Press SHIFT" banner           │  │
│  │  └─ If Shift held → root bash shell         │  │
│  │  └─ Exit → continues boot                   │  │
│  └────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────┐  │
│  │  Every boot (after graphical.target):       │  │
│  │  chaossynergy-launcher.service                 │  │
│  │  └─ tmux session "chaossynergy"                │  │
│  │  └─ Main pane: distrobox enter hermes       │  │
│  │  └─ Ctrl+B r → recovery window              │  │
│  │  └─ Ctrl+B d → detach to GNOME desktop      │  │
│  └────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────┐  │
│  │  Background (scenario, Phase 3+):           │  │
│  │  Bootc auto-updates                         │  │
│  │  └─ bootc upgrade (systemd timer)            │  │
│  │  └─ Staged deployment, rollback on failure  │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

---

## 6. Comparison to Other Projects

| Project | Base | Desktop | Customization | Agent |
|---------|------|---------|---------------|-------|
| **[Chaossynergy](https://github.com/dark5un/chaossynergy)** | Bluefin DX NVIDIA | GNOME (fallback) | TUI agent launcher + systemd services | Hermes in distrobox |
| **[bOS](https://github.com/bsherman/bos)** | Bazzite | KDE/GNOME | Packages, configs | None |
| **[m2OS](https://github.com/m2Giles/m2os)** | Bluefin/Bazzite | KDE/GNOME | Docker, Incus, Steam | None |
| **[Amy OS](https://github.com/astrovm/amyos)** | Bazzite | KDE | Waydroid, dev tools, Flatpaks | None |
| **[VeneOS](https://github.com/Venefilyn/veneos)** | Bazzite | GNOME | Dev tools, Flatpaks | None |
| **[Homer](https://github.com/bketelsen/homer/)** | uCore | None | Homelab services | None |

Chaossynergy is unique in being **agent-first** — the OS exists to serve the agent, not the other way around. Every other custom image is "take an existing OS and add my apps." Chaossynergy is "take an OS and make it an agent appliance."

---

## 7. Roadmap

| Phase | What | Status |
|-------|------|--------|
| **1. Image Customization** | Switch base to bluefin-dx-nvidia, add packages, systemd services, launcher | ✅ Done |
| **2. Local Testing** | Build QCOW2, boot in QEMU, verify first-boot flow | 🔄 On hold |
| **3. CI Validation** | GitHub Actions building + signing + disk images | ✅ CI passes |
| **4. Installer ISO** | Build bootc-installer for bare-metal install | ⏳ Next |
| **5. Migration to finpilot** | Multi-stage OCI assembly for maintainability | 🔮 Future |
| **6. Graphical Launcher** | Native agent UI (GTK/QML) replacing tmux | 🔮 Future |
| **7. Minimal Base** | Optionally strip GNOME, build from base-main | 🔮 Future |

---

## 8. Glossary

| Term | Definition |
|------|------------|
| **bootc** | CLI tool and spec for bootable OCI container images |
| **OCI image** | The standard container image format (what Docker uses) |
| **bootc-image-builder** | Tool that converts a bootc container image into a bootable disk image |
| **Universal Blue (uBlue)** | Community building production bootc images on Fedora/CentOS |
| **Bluefin** | uBlue's developer-focused GNOME desktop image |
| **Bluefin DX** | Bluefin with extra dev tools (Docker, Homebrew, distrobox, etc.) |
| **image-template** | The original Git repository template for building custom uBlue images |
| **finpilot** | Bluefin's newer multi-stage OCI assembly template |
| **distrobox** | Tool for creating disposable container-based development environments |
| **GHCR** | GitHub Container Registry — where our OCI images are published |
| **cosign** | Container image signing tool for supply-chain security |
| **SBOM** | Software Bill of Materials — a list of all packages in the image |
| **QCOW2** | QEMU disk image format — used for VM testing |
| **Anaconda** | Fedora's installer (used in anaconda-iso) |
| **bootc switch** | The command to switch a running system to a different bootc image |
| **ujust** | Bluefin's custom `just` recipe system for user commands |
| **akmods** | Kernel module packages (e.g., NVIDIA drivers built per-kernel) |