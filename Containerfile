# Chaossynergy — CentOS Stream 10 (Bluefin LTS base)
# Agent-native immutable Linux. The OS is the agent interface.
#
# Built on Bluefin LTS (CentOS Stream 10) for stability.
# Our overlay adds herdr, branding, and the agent environment.

ARG BASE_IMAGE="ghcr.io/projectbluefin/bluefin-lts"
ARG BASE_TAG="stable"

FROM ${BASE_IMAGE}:${BASE_TAG}

# ── Chaossynergy overlay ──────────────────────────────────────────
COPY chaos_files/ /chaos/
RUN bash /chaos/build.sh && rm -rf /chaos

CMD ["/sbin/init"]