# Chaossynergy — CentOS Stream 10 (Bluefin LTS base)
# Agent-native immutable Linux. The OS is the agent interface.
#
# Built on Bluefin LTS (CentOS Stream 10) for stability.
# Our overlay adds herdr, branding, and the agent environment.

ARG BASE_IMAGE="ghcr.io/projectbluefin/bluefin-lts"
ARG BASE_TAG=stable

# Auto-connect the image to this repo so GITHUB_TOKEN has write access
LABEL org.opencontainers.image.source="https://github.com/dark5un/chaossynergy"
LABEL org.opencontainers.image.description="Chaossynergy — Agent-native immutable Linux"
LABEL org.opencontainers.image.licenses="Apache-2.0"

FROM ghcr.io/projectbluefin/bluefin-lts:${BASE_TAG}

# ── Chaossynergy overlay ──────────────────────────────────────────
COPY chaos_files/ /chaos/
RUN bash /chaos/build.sh && rm -rf /chaos

CMD ["/sbin/init"]