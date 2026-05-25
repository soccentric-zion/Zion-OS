#!/bin/bash
# post-install.sh — SWUpdate A/B post-install hook for KR260
#
# Activates the newly written slot by setting U-Boot environment variables:
#   bootslot         = a | b   (which rootfs partition to boot next)
#   upgrade_available = 1       (tell U-Boot this is an unconfirmed upgrade)
#   bootcount         = 0       (reset retry counter)
#
# On the next boot U-Boot reads these variables and boots from the new slot.
# After a successful boot the swupdate-bootcheck.service confirms the upgrade
# by setting upgrade_available=0 via fw_setenv.
#
# U-Boot env storage location is configured in /etc/fw_env.config.

set -euo pipefail

log() { echo "swupdate-post-install: $*" >&2; }

TARGET_SLOT_FILE="/run/swupdate-target-slot"

if [ ! -f "$TARGET_SLOT_FILE" ]; then
    log "ERROR: $TARGET_SLOT_FILE not found. Did pre-install.sh run?"
    exit 1
fi

TARGET_SLOT=$(cat "$TARGET_SLOT_FILE")

if [ "$TARGET_SLOT" != "a" ] && [ "$TARGET_SLOT" != "b" ]; then
    log "ERROR: Invalid target slot '$TARGET_SLOT' in $TARGET_SLOT_FILE."
    exit 1
fi

log "Activating slot: $TARGET_SLOT"

fw_setenv bootslot          "$TARGET_SLOT"
fw_setenv upgrade_available 1
fw_setenv bootcount         0

log "U-Boot env updated — will boot from rootfs-${TARGET_SLOT} on next reboot."
