#!/bin/bash
# Chaossynergy Niri — Post-build overlay (no-GNOME path)
# Base: ghcr.io/ublue-os/base-nvidia (Fedora Atomic, NVIDIA, no desktop)
set -oue pipefail

echo "[chaossynergy-niri] Applying overlay..."

# ── Copy our system files into the image ──────────────────────────────
cp -r /chaos/system_files/usr/bin/* /usr/bin/
cp -r /chaos/system_files/usr/libexec/* /usr/libexec/
cp -r /chaos/system_files/usr/lib/systemd/system/* /usr/lib/systemd/system/
mkdir -p /usr/lib/systemd/user
cp -r /chaos/system_files/usr/lib/systemd/user/* /usr/lib/systemd/user/
cp -r /chaos/system_files/usr/lib/tmpfiles.d/* /usr/lib/tmpfiles.d/
cp -r /chaos/system_files/usr/share/backgrounds/* /usr/share/backgrounds/
cp -r /chaos/system_files/usr/share/ublue-os/just/* /usr/share/ublue-os/just/ 2>/dev/null || true
chmod -R 755 /usr/bin/chaossynergy /usr/bin/chaossynergy-shell /usr/libexec/hermes/

# ── Install niri (Wayland compositor) + Wayland session tooling ───────
# niri is in the Fedora repos; niri-session wires up D-Bus + portals.
dnf install -y niri || true

# Ghostty is COPR-only (not in vanilla Fedora). Enable the official build
# before installing it as the default terminal.
curl -fsSL --retry 3 -o /etc/yum.repos.d/_copr_scottames-ghostty.repo \
  "https://copr.fedorainfracloud.org/coprs/scottames/ghostty/repo/fedora-$(rpm -E %fedora)/scottames-ghostty-fedora-$(rpm -E %fedora).repo"

# GNOME-free companion stack for a usable agent desktop:
#   ghostty  — fast GPU-accelerated terminal emulator that herdr runs inside
#   grim/slurp/swappy — screenshots (wayland-native)
#   wl-clipboard      — clipboard for the agent
#   xdg-desktop-portal — portals for file dialogs
#   fuzzel   — app launcher
#   swaylock/swayidle — session lock + idle
dnf install -y ghostty grim slurp swappy wl-clipboard \
    xdg-desktop-portal xdg-desktop-portal-gtk \
    polkit polkit-pkla-compat \
    fuzzel swaylock swayidle || true

# ── Install distrobox (agent containers) + herdr (agent multiplexer) ──
# distrobox from the Fedora package (reliable in podman build); its curl
# installer collides with the pre-existing /usr/local in this image.
dnf install -y distrobox

curl -fsSL --retry 3 -o /tmp/herdr \
  https://github.com/ogulcancelik/herdr/releases/download/v0.7.3/herdr-linux-x86_64
install -m 0755 /tmp/herdr /usr/bin/herdr
rm -f /tmp/herdr

# ── Source Code Pro Nerd Font (Ghostty + agent UI) ────────────────────
# Nerd Fonts build keeps glyphs needed by herdr/TUI tooling.
SCP_DIR="/usr/share/fonts/source-code-pro-nerd"
mkdir -p "$SCP_DIR"
curl -fsSL --retry 3 -o /tmp/scp.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/SourceCodePro.zip
unzip -o /tmp/scp.zip -d "$SCP_DIR" 2>/dev/null || true
rm -f /tmp/scp.zip
fc-cache -f "$SCP_DIR" 2>/dev/null || true

# Ghostty default font — Source Code Pro Nerd Font, 13pt
mkdir -p /etc/ghostty
cat > /etc/ghostty/config << 'EOF'
font-family = "Source Code Pro Nerd Font"
font-size = 13
theme = "tokyonight"
EOF

# ── Niri compositor config ─────────────────────────────────────────────
mkdir -p /etc/niri
cp /chaos/system_files/usr/share/chaossynergy/niri/config.kdl /etc/niri/config.kdl

# ── Services ───────────────────────────────────────────────────────────
systemctl enable podman.socket || true
systemctl enable chaossynergy-recovery.service || true

# ── Create default user (no GDM — base-nvidia uses getty on tty1) ─────
# Autologin via getty override; user owns the graphical session.
useradd -m -G wheel -s /bin/bash aiagent 2>/dev/null || true
passwd -d aiagent 2>/dev/null || true

# Enable getty autologin for the aiagent user (arbitrary-VT based session)
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin aiagent --noclear %I $TERM
EOF
systemctl enable getty@tty1.service || true

# Default to the niri session for the aiagent user on graphical login
cat > /home/aiagent/.bash_profile << 'EOF'
if [ "$(tty)" = "/dev/tty1" ]; then
    export XDG_SESSION_TYPE=wayland
    export XDG_CURRENT_DESKTOP=niri

    # Ensure XDG_RUNTIME_DIR exists — raw agetty autologin may not provide it.
    if [ -z "${XDG_RUNTIME_DIR}" ] || [ ! -d "${XDG_RUNTIME_DIR}" ]; then
        export XDG_RUNTIME_DIR="/run/user/$(id -u)"
        mkdir -p "$XDG_RUNTIME_DIR"
        chmod 700 "$XDG_RUNTIME_DIR"
    fi

    # Start niri-session. On failure, log the error to a file and drop to a
    # shell so the crash is debuggable instead of looping back to the login.
    if niri-session >/tmp/niri-session.log 2>&1; then
        exit 0
    else
        echo "[chaossynergy] niri-session failed (see /tmp/niri-session.log). Dropping to shell."
        cat /tmp/niri-session.log
        exec bash --noprofile --norc
    fi
fi
EOF
chown aiagent:aiagent /home/aiagent/.bash_profile 2>/dev/null || true

echo "[chaossynergy-niri] Overlay complete."
