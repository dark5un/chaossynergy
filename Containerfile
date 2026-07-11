ARG BASE_IMAGE_NAME="silverblue"
ARG FEDORA_MAJOR_VERSION="42"
ARG SOURCE_IMAGE="${BASE_IMAGE_NAME}-main"
ARG BASE_IMAGE="ghcr.io/ublue-os/${SOURCE_IMAGE}"
ARG COMMON_IMAGE="ghcr.io/projectbluefin/common:latest"
ARG COMMON_IMAGE_SHA=""
ARG BREW_IMAGE="ghcr.io/ublue-os/brew:latest"
ARG BREW_IMAGE_SHA=""

FROM ${COMMON_IMAGE}@${COMMON_IMAGE_SHA} AS common
FROM ${BREW_IMAGE}@${BREW_IMAGE_SHA} AS brew

FROM scratch AS ctx
COPY /build_files /build_files
COPY --from=common /system_files/shared /system_files/shared
COPY --from=common /system_files/bluefin /system_files/shared
COPY --from=brew /system_files /system_files/shared
# bluefin-owned files overlay last so they take precedence over common
COPY /system_files /system_files

## bluefin image section
FROM ${BASE_IMAGE}:${FEDORA_MAJOR_VERSION} AS base

ARG AKMODS_FLAVOR="coreos-stable"
ARG BASE_IMAGE_NAME="silverblue"
ARG FEDORA_MAJOR_VERSION="40"
ARG IMAGE_NAME="bluefin"
ARG IMAGE_VENDOR="ublue-os"
ARG KERNEL="6.10.10-200.fc40.x86_64"
ARG SHA_HEAD_SHORT="dedbeef"
ARG UBLUE_IMAGE_TAG="stable"
ARG VERSION=""
ARG IMAGE_FLAVOR=""

# ── Pre-build workarounds (upstream Bluefin F44/GNOME 50) ─────────
RUN mkdir -p /usr/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com/schemas \
    /usr/share/gnome-shell/extensions/tmp/bazaar-integration@kolunmi.github.io/src/ \
    /usr/share/gnome-shell/extensions/bazaar-integration@kolunmi.github.io
# F44: blur-my-shell extension ships without a Makefile
RUN if [ -d /usr/share/gnome-shell/extensions/blur-my-shell@aunetx ] && [ ! -f /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/Makefile ]; then \
      printf 'all:\n	@echo "blur-my-shell: no-op"\n' > /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/Makefile; \
    fi
# F44: caffeine extension tmp dir may not exist
RUN mkdir -p /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info \
    /usr/share/gnome-shell/extensions/caffeine@patapon.info
# F44: pre-create blur-my-shell build zip source (unzip succeeds even if empty)
RUN mkdir -p /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build \
    && printf 'PK\x05\x06\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00' > /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip

# Build, cleanup, lint (with F44 compatibility patches).
COPY chaos_files/patch-and-build.sh /tmp/patch-and-build.sh
RUN --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=secret,id=GITHUB_TOKEN \
    bash /tmp/patch-and-build.sh

# ── Chaossynergy overlay ──────────────────────────────────────────
COPY chaos_files/ /tmp/chaos/
RUN bash /tmp/chaos/build.sh && rm -rf /tmp/chaos

# Makes `/opt` writeable by default
# Needs to be here to make the main image build strict (no /opt there)
# This is for downstream images/stuff like k0s
RUN rm -rf /opt && ln -s /var/opt /opt

CMD ["/sbin/init"]

RUN bootc container lint