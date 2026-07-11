#!/bin/bash
# Run Bluefin's build.sh (with pre-applied patches from Containerfile).
set -eoux pipefail
exec /ctx/build_files/shared/build.sh