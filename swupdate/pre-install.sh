#!/bin/bash
# SWUpdate pre-install script — included in every .swu package
#
# Identifies the inactive rootfs slot using partition labels (rootfs-a /
# rootfs-b) and creates the /dev/swupdate-inactive symlink that the "raw"
# image handler in sw-description writes to.
# Saves the target slot to /run/ for use by post-install.sh.
#
# KR260 SD card layout (mmcblk1):
#   p1  /boot      FAT32   — BOOT.BIN + Image + DTB
#   p2  rootfs-a   ext4    — A-slot root
#   p3  rootfs-b   ext4    — B-slot root
#   p4  /home      ext4    — Persistent data

set -euo pipefail

log() { echo "[swupdate pre-install] $*" >&2; }

# ── Find the currently active root device ────────────────────────────────────
ACTIVE_DEV=$(findmnt -n -o SOURCE /)
log "Active root: ${ACTIVE_DEV}"

# ── Resolve partition labels ──────────────────────────────────────────────────
DEV_A=$(blkid -L rootfs-a 2>/dev/null || true)
DEV_B=$(blkid -L rootfs-b 2>/dev/null || true)

if [ -z "${DEV_A}" ] || [ -z "${DEV_B}" ]; then
    log "ERROR: Cannot find partitions with labels rootfs-a / rootfs-b."
    log "       Ensure the SD card was flashed with sdimage-zynqmp.wks."
    exit 1
fi

# ── Pick the inactive slot ────────────────────────────────────────────────────
if [ "${ACTIVE_DEV}" = "${DEV_A}" ]; then
    INACTIVE_DEV="${DEV_B}"
    INACTIVE_SLOT=b
elif [ "${ACTIVE_DEV}" = "${DEV_B}" ]; then
    INACTIVE_DEV="${DEV_A}"
    INACTIVE_SLOT=a
else
    log "ERROR: Active root '${ACTIVE_DEV}' does not match rootfs-a (${DEV_A}) or rootfs-b (${DEV_B})."
    exit 1
fi

log "Target slot: ${INACTIVE_SLOT} (${INACTIVE_DEV})"

# ── Ensure the inactive partition is not mounted ──────────────────────────────
if mountpoint -q /mnt/rootfs-inactive 2>/dev/null; then
    umount /mnt/rootfs-inactive
fi

# ── Create the stable symlink the image handler will write to ─────────────────
ln -sf "${INACTIVE_DEV}" /dev/swupdate-inactive

# ── Persist slot info for post-install ────────────────────────────────────────
echo "${INACTIVE_SLOT}" > /run/swupdate-target-slot
echo "${INACTIVE_DEV}"  > /run/swupdate-target-dev
