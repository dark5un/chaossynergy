#!/bin/bash
# Patch Bluefin's build-gnome-extensions.sh for F44 compatibility
# Called from Containerfile before the main build step.
# Uses simple cp/overwrite instead of inline sed to avoid escaping hell.

SCRIPT="/ctx/build_files/shared/build-gnome-extensions.sh"

# Patch 1: blur-my-shell make — guard against missing Makefile
sed -i 's|^make -C /usr/share/gnome-shell/extensions/blur-my-shell@aunetx$|if [ -f /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/Makefile ]; then make -C /usr/share/gnome-shell/extensions/blur-my-shell@aunetx; else echo "blur-my-shell: skipped (no Makefile)"; fi|' "$SCRIPT"

# Patch 2: blur-my-shell unzip — guard against missing build artifact
sed -i 's|^unzip -o /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip -d /usr/share/gnome-shell/extensions/blur-my-shell@aunetx$|ZIP=/usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip; if [ -f "$ZIP" ]; then unzip -o "$ZIP" -d /usr/share/gnome-shell/extensions/blur-my-shell@aunetx; else echo "blur-my-shell: unzip skipped"; fi|' "$SCRIPT"

# Patch 3: caffeine mv — guard against missing source dir
sed -i 's|^mv /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info /usr/share/gnome-shell/extensions/caffeine@patapon.info$|SRC=/usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info; if [ -d "$SRC" ]; then mv "$SRC" /usr/share/gnome-shell/extensions/caffeine@patapon.info; else echo "caffeine: skipped"; fi|' "$SCRIPT"

# Now run the actual Bluefin build
exec /ctx/build_files/shared/build.sh