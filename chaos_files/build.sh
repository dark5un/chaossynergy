#!/bin/bash
# Chaossynergy — Post-build overlay
set -oue pipefail

echo "[chaossynergy] Applying overlay..."

# Copy our system files into the image
cp -r /chaos/system_files/usr/bin/* /usr/bin/
cp -r /chaos/system_files/usr/libexec/* /usr/libexec/
cp -r /chaos/system_files/usr/lib/systemd/system/* /usr/lib/systemd/system/
mkdir -p /usr/lib/systemd/user
cp -r /chaos/system_files/usr/lib/systemd/user/* /usr/lib/systemd/user/
cp -r /chaos/system_files/usr/lib/tmpfiles.d/* /usr/lib/tmpfiles.d/
cp -r /chaos/system_files/usr/share/anaconda/* /usr/share/anaconda/
cp -r /chaos/system_files/usr/share/backgrounds/* /usr/share/backgrounds/
cp -r /chaos/system_files/usr/share/icons/* /usr/share/icons/
# Ensure scripts are readable+executable (cp preserves source perms which may be too restrictive)
chmod -R 755 /usr/bin/chaossynergy /usr/bin/chaossynergy-shell /usr/libexec/hermes/

# ── Install herdr ─────────────────────────────────────────────────
curl -fsSL --retry 3 -o /tmp/herdr \
  https://github.com/ogulcancelik/herdr/releases/download/v0.7.3/herdr-linux-x86_64
install -m 0755 /tmp/herdr /usr/bin/herdr
rm -f /tmp/herdr

# ── Install distrobox (not in CentOS LTS minimal base) ─────────────
curl -fsSL --retry 3 https://raw.githubusercontent.com/89luca89/distrobox/main/install | sh -s -- --prefix /usr/local

# ── Install JetBrains Mono Nerd Font ────────────────────────────────
JBM_DIR="/usr/share/fonts/jetbrains-mono-nerd"
mkdir -p "$JBM_DIR"
curl -fsSL --retry 3 -o /tmp/jbm.zip \
  https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip
unzip -o /tmp/jbm.zip -d "$JBM_DIR" 2>/dev/null || true
rm -f /tmp/jbm.zip
fc-cache -f "$JBM_DIR" 2>/dev/null || true

# ── Enable services ───────────────────────────────────────────────
systemctl enable podman.socket || true
systemctl enable chaossynergy-recovery.service || true

# User service — auto-enable herdr for all users on login
mkdir -p /etc/systemd/user/graphical-session.target.wants
ln -sf /usr/lib/systemd/user/chaossynergy-herdr.service /etc/systemd/user/graphical-session.target.wants/chaossynergy-herdr.service || true

# Disable GNOME Initial Setup (we create the user ourselves)
systemctl disable gnome-initial-setup.service 2>/dev/null || true
systemctl mask gnome-initial-setup.service 2>/dev/null || true
# Disable GNOME welcome tour
cat > /etc/dconf/db/distro.d/00_chaossynergy-tour << 'EOF'
[org/gnome/shell]
welcome-dialog-last-shown-version='99999'
EOF
dconf update || true

# ── Create default user (avoids GNOME Initial Setup hang) ────────
# No password — auto-login via GDM. User sets password on first session.
useradd -m -G wheel -s /bin/bash aiagent 2>/dev/null || true
passwd -d aiagent 2>/dev/null || true

# ── Auto-login ────────────────────────────────────────────────────
cat > /etc/gdm/custom.conf << 'EOF'
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=aiagent
EOF

# ── Branding ──────────────────────────────────────────────────────
cat > /usr/share/glib-2.0/schemas/80_chaossynergy-wallpaper.gschema.override << 'EOF'
[org.gnome.desktop.background]
picture-uri='file:///usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png'
picture-uri-dark='file:///usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png'
picture-options='zoom'
primary-color='#050508'
secondary-color='#050508'
[org.gnome.desktop.screensaver]
picture-uri='file:///usr/share/backgrounds/chaossynergy/chaossynergy-wallpaper.png'
EOF
glib-compile-schemas /usr/share/glib-2.0/schemas/ || true

mkdir -p /usr/share/pixmaps
cp /usr/share/icons/hicolor/scalable/apps/chaossynergy.svg /usr/share/pixmaps/chaossynergy.svg || true

echo "[chaossynergy] Overlay complete."