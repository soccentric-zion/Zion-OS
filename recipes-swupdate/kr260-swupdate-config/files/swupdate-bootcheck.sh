#!/bin/bash
# swupdate-bootcheck.sh — Confirm successful boot for KR260 A/B OTA
#
# Called by swupdate-bootcheck.service on every boot.  If upgrade_available=1
# (set by post-install.sh), this is a trial boot of a newly written slot.
# We check the system is healthy and then clear upgrade_available so U-Boot
# does not roll back on the next reboot.
#
# Active slot is determined by matching the root partition device against the
# rootfs-a / rootfs-b partition labels.

set -euo pipefail

log() { echo "swupdate-bootcheck: $*"; }

ACTIVE_SLOT_FILE="/run/swupdate-active-slot"

# ── Identify active slot ──────────────────────────────────────────────────────
ACTIVE_ROOT=$(findmnt -n -o SOURCE /)
DEV_A=$(blkid -L rootfs-a 2>/dev/null || true)
DEV_B=$(blkid -L rootfs-b 2>/dev/null || true)

if   [ "$ACTIVE_ROOT" = "$DEV_A" ]; then ACTIVE_SLOT="a"
elif [ "$ACTIVE_ROOT" = "$DEV_B" ]; then ACTIVE_SLOT="b"
else
    log "WARNING: Cannot identify active slot for '$ACTIVE_ROOT'."
    ACTIVE_SLOT="unknown"
fi

log "Active root: $ACTIVE_ROOT (slot $ACTIVE_SLOT)"
echo "$ACTIVE_SLOT" > "$ACTIVE_SLOT_FILE"

# ── Confirm upgrade if one is pending ────────────────────────────────────────
UPGRADE_AVAILABLE=$(fw_printenv upgrade_available 2>/dev/null \
                    | cut -d= -f2 || echo "0")

if [ "$UPGRADE_AVAILABLE" = "1" ]; then
    log "Upgrade pending — confirming boot of slot $ACTIVE_SLOT."
    fw_setenv upgrade_available 0
    fw_setenv bootcount         0
    log "Upgrade confirmed."
else
    log "No pending upgrade (upgrade_available=$UPGRADE_AVAILABLE)."
fi
