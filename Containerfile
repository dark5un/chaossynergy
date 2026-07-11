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

# Build, cleanup, lint (with F44 compatibility patches).
RUN --mount=type=cache,dst=/var/cache/libdnf5 \
    --mount=type=cache,dst=/var/cache/rpm-ostree \
    --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=secret,id=GITHUB_TOKEN \
    sed -i 's|^make -C /usr/share/gnome-shell/extensions/blur-my-shell@aunetx$|test -f /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/Makefile \&\& make -C /usr/share/gnome-shell/extensions/blur-my-shell@aunetx || echo "blur-my-shell: skipped"|' /ctx/build_files/shared/build-gnome-extensions.sh \
    && sed -i 's|^unzip -o /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip|test -f /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip \&\& unzip -o /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip || echo "blur-my-shell: unzip skipped"|' /ctx/build_files/shared/build-gnome-extensions.sh \
    && sed -i 's|^mv /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info|test -d /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info \&\& mv /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info || echo "caffeine: skipped"|' /ctx/build_files/shared/build-gnome-extensions.sh \
    && /ctx/build_files/shared/build.sh

# ── Chaossynergy overlay ──────────────────────────────────────────
COPY chaos_files/ /tmp/chaos/
RUN bash /tmp/chaos/build.sh && rm -rf /tmp/chaos

# Makes `/opt` writeable by default
# Needs to be here to make the main image build strict (no /opt there)
# This is for downstream images/stuff like k0s
RUN rm -rf /opt && ln -s /var/opt /opt

CMD ["/sbin/init"]

RUN bootc container lint