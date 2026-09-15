#!/usr/bin/env bash
# test-wiring.sh — bitbake-build ONLY WebConfig + Instrumentation.
#
# Unlike build.sh (which builds the full image, thousands of tasks), this
# targets just the handful of recipes that matter for validating the
# Configuration/Instrumentation wiring: it runs
#   kas-container shell kas/boards/$(BOARD).yaml -c "bitbake <targets>"
# which builds only those recipes and their actual dependency chain, not
# the whole OS image. Vastly faster to iterate on.
#
# Usage:
#   ./test-wiring.sh            # default board (see Makefile: BOARD ?=)
#   ./test-wiring.sh BOARD_NAME # a specific board

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

if [[ $# -ge 1 ]]; then
    exec make test-wiring "BOARD=$1"
else
    exec make test-wiring
fi
