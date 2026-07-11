#!/bin/bash
# Runs INSIDE the build mount — fixes F44 extension issues before
# Bluefin's build-gnome-extensions.sh runs.
set -eoux pipefail

EXT="/usr/share/gnome-shell/extensions"
BUILD_GNOME="/ctx/build_files/shared/build-gnome-extensions.sh"

# Create missing directories that extensions script expects
mkdir -p "${EXT}/appindicatorsupport@rgcjonas.gmail.com/schemas"
mkdir -p "${EXT}/tmp/bazaar-integration@kolunmi.github.io/src/"
mkdir -p "${EXT}/bazaar-integration@kolunmi.github.io"
mkdir -p "${EXT}/tmp/caffeine/caffeine@patapon.info"
mkdir -p "${EXT}/caffeine@patapon.info"

# blur-my-shell: create dummy Makefile + empty zip (no-op build)
if [ -d "${EXT}/blur-my-shell@aunetx" ]; then
    mkdir -p "${EXT}/blur-my-shell@aunetx/build"
    printf 'all:\n\t@echo "blur-my-shell: skipped"\n' > "${EXT}/blur-my-shell@aunetx/Makefile"
    printf '\x50\x4b\x05\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > "${EXT}/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip"
fi

exec /ctx/build_files/shared/build.sh