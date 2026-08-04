# Chaossynergy Niri — Fedora base (base-nvidia), no desktop, agent-native
# The OS is the agent interface. Niri is the compositor; herdr is the surface.
#
# Built on ghcr.io/ublue-os/base-nvidia — Fedora Atomic, no desktop layer,
# NVIDIA drivers + nvidia-container-toolkit pre-baked for GPU acceleration.

ARG BASE_IMAGE="ghcr.io/ublue-os/base-nvidia"
ARG BASE_TAG=latest

FROM ${BASE_IMAGE}:${BASE_TAG}

# Auto-connect the image to this repo so GITHUB_TOKEN has write access
LABEL org.opencontainers.image.source="https://github.com/dark5un/chaossynergy"
LABEL org.opencontainers.image.description="Chaossynergy Niri — agent-native minimal Linux"
LABEL org.opencontainers.image.licenses="Apache-2.0"

# ── Chaossynergy Niri overlay ──────────────────────────────────────────
COPY chaos_files/ /chaos/
RUN bash /chaos/build.sh && rm -rf /chaos

CMD ["/sbin/init"]
