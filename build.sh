#!/usr/bin/env bash
# build.sh — build this project's Yocto image.
#
# Thin wrapper around this repo's own Makefile, which drives kas-container
# -> bitbake under the hood (`make build` -> `kas-container build
# kas/boards/$(BOARD).yaml` -> `bitbake -c build <image>` inside the kas
# docker container). Builds the KAS docker image first if it doesn't exist
# yet (ensure-image, a dependency of the `build` target).
#
# Usage:
#   ./build.sh            # build the default board (see Makefile: BOARD ?=)
#   ./build.sh BOARD_NAME # build a specific board (must match kas/boards/<name>.yaml)
#
# Real Yocto builds take a long time (minutes to hours depending on sstate
# cache state) — this runs in the foreground; use `nohup ./build.sh &` or
# project-managers/script/build-all.sh to run it in the background with
# logging.

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ $# -ge 1 ]]; then
    exec make build "BOARD=$1"
else
    exec make build
fi
