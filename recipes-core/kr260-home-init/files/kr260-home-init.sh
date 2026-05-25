#!/bin/bash
# kr260-home-init.sh — Initialise /home/zion on the persistent data partition
# (p4, label "home") and expand it to fill the SD card on first boot.
# Runs once; a flag file prevents repeated execution.

set -euo pipefail

FLAG="/home/.home-initialised"
ZION_HOME="/home/zion"

# ── Guard ────────────────────────────────────────────────────────────────────
if [ -f "$FLAG" ]; then
    echo "kr260-home-init: already done, skipping."
    exit 0
fi

# ── Create zion user home directory ─────────────────────────────────────────
echo "kr260-home-init: initialising $ZION_HOME ..."
install -d -o zion -g zion -m 0750 "$ZION_HOME"

# ── Expand data partition to fill available SD card space ───────────────────
# Find the block device backing /home (the persistent data partition p4).
HOME_DEV=$(findmnt -n -o SOURCE /home 2>/dev/null || true)

if [ -n "$HOME_DEV" ]; then
    HOME_DEV_NAME="${HOME_DEV#/dev/}"
    if [[ "$HOME_DEV_NAME" =~ ^(mmcblk[0-9]+)p([0-9]+)$ ]]; then
        DISK_DEV="/dev/${BASH_REMATCH[1]}"
        PART_NUM="${BASH_REMATCH[2]}"
        echo "kr260-home-init: expanding partition $PART_NUM on $DISK_DEV ..."
        parted -s "$DISK_DEV" resizepart "$PART_NUM" 100%
        partprobe "$DISK_DEV" 2>/dev/null || true
        udevadm settle
        resize2fs "$HOME_DEV"
        echo "kr260-home-init: resize complete."
    fi
fi

touch "$FLAG"
echo "kr260-home-init: done."
