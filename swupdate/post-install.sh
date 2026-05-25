#!/bin/bash
# SWUpdate post-install script — included in every .swu package
#
# Activates the newly written A/B slot by updating U-Boot environment
# variables via fw_setenv (libubootenv-bin).  On the next reboot U-Boot
# reads bootslot and boots from the appropriate partition.
#
# After a successful boot, swupdate-bootcheck.service confirms the upgrade
# by calling fw_setenv upgrade_available 0.

set -euo pipefail

log() { echo "[swupdate post-install] $*" >&2; }

TARGET_SLOT=$(cat /run/swupdate-target-slot)
TARGET_DEV=$(cat  /run/swupdate-target-dev)

log "Activating slot ${TARGET_SLOT} (${TARGET_DEV})"

# ── Update U-Boot environment to boot from new slot ──────────────────────────
fw_setenv bootslot          "${TARGET_SLOT}"
fw_setenv upgrade_available 1
fw_setenv bootcount         0

log "U-Boot env: bootslot=${TARGET_SLOT} upgrade_available=1 bootcount=0"

# ── Clean up temporary files and symlink ─────────────────────────────────────
rm -f /dev/swupdate-inactive \
      /run/swupdate-target-slot \
      /run/swupdate-target-dev
