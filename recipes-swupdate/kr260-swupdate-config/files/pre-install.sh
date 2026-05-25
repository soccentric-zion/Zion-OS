#!/bin/bash
# pre-install.sh — SWUpdate A/B pre-install hook for KR260
#
# Determines the inactive root partition (the one NOT currently mounted as /)
# using partition labels (rootfs-a / rootfs-b) and creates a stable
# /dev/swupdate-inactive symlink that the sw-description raw handler uses.
#
# Partition layout (SD card, typically mmcblk1):
#   p1  /boot      FAT32     BOOT.BIN + Image + DTB
#   p2  rootfs-a   ext4      A-slot root
#   p3  rootfs-b   ext4      B-slot root
#   p4  /home      ext4      persistent data

set -euo pipefail

log() { echo "swupdate-pre-install: $*" >&2; }

# ── Detect active root partition ─────────────────────────────────────────────
ACTIVE_ROOT=$(findmnt -n -o SOURCE /)
log "Active root: $ACTIVE_ROOT"

# ── Resolve partition labels ──────────────────────────────────────────────────
DEV_A=$(blkid -L rootfs-a 2>/dev/null || true)
DEV_B=$(blkid -L rootfs-b 2>/dev/null || true)

if [ -z "$DEV_A" ] || [ -z "$DEV_B" ]; then
    log "ERROR: Cannot find partitions with labels rootfs-a / rootfs-b."
    log "       Ensure the SD card was flashed with sdimage-zynqmp.wks."
    exit 1
fi

# ── Pick the inactive slot ────────────────────────────────────────────────────
if [ "$ACTIVE_ROOT" = "$DEV_A" ]; then
    INACTIVE="$DEV_B"
    TARGET_SLOT="b"
elif [ "$ACTIVE_ROOT" = "$DEV_B" ]; then
    INACTIVE="$DEV_A"
    TARGET_SLOT="a"
else
    log "ERROR: Active root '$ACTIVE_ROOT' does not match rootfs-a ($DEV_A) or rootfs-b ($DEV_B)."
    exit 1
fi

log "Inactive slot: $TARGET_SLOT ($INACTIVE)"

# ── Create stable symlink for sw-description ─────────────────────────────────
ln -sf "$INACTIVE" /dev/swupdate-inactive
log "Symlink: /dev/swupdate-inactive -> $INACTIVE"

# ── Persist target slot so post-install.sh can read it ───────────────────────
echo "$TARGET_SLOT" > /run/swupdate-target-slot
