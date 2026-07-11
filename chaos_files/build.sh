#!/bin/bash
# Chaossynergy — Post-build overlay
# Runs AFTER Bluefin's build.sh to apply our customizations.
set -ouex pipefail

echo "[chaossynergy] Applying overlay..."

# Copy our system files into the image
cp -r /chaos/system_files/usr/ /usr/
cp -r /chaos/system_files/etc/ /etc/

# ── Install herdr ─────────────────────────────────────────────────
curl -fsSL --retry 3 -o /tmp/herdr \
  https://github.com/ogulcancelik/herdr/releases/download/v0.7.3/herdr-linux-x86_64
install -m 0755 /tmp/herdr /usr/bin/herdr
rm -f /tmp/herdr

# ── Enable services ───────────────────────────────────────────────
systemctl enable podman.socket
# Launcher service is NOT enabled — herdr runs via GNOME autostart
systemctl enable chaossynergy-recovery.service

# ── Branding ──────────────────────────────────────────────────────
# Set default wallpaper (gschema override for new users)
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
glib-compile-schemas /usr/share/glib-2.0/schemas/

# Set system icon
mkdir -p /usr/share/pixmaps
cp /usr/share/icons/hicolor/scalable/apps/chaossynergy.svg /usr/share/pixmaps/chaossynergy.svg || true

echo "[chaossynergy] Overlay complete."