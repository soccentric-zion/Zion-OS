#!/usr/bin/env bash
# generate-flash-sdcard.sh — write a self-contained SD-card flasher into an
# image deploy directory.
#
# Called automatically by `make deploy-images` right after the .wic.bz2 /
# .wic.bmap artifacts are copied, so every deploy/images/BOARD_TS/ folder
# ships with its own flash script and stays usable on any host without the
# Zion-OS repo.
#
# Usage:
#   scripts/generate-flash-sdcard.sh <outdir> [<board>] [<timestamp>]

set -euo pipefail

out="${1:?usage: generate-flash-sdcard.sh <outdir> [<board>] [<timestamp>]}"
board="${2:-}"
ts="${3:-}"

mkdir -p "$out"
script="$out/flash-sdcard.sh"

# Header (interpolated: board/timestamp stamped in) ...
{
    printf '#!/usr/bin/env bash\n'
    printf '# flash-sdcard.sh — Zion-OS%s SD card image flasher\n' \
        "$([ -n "$board" ] && printf ' %s' "$board")"
    printf '# Auto-generated from the Zion-OS build%s do not edit.\n' \
        "$([ -n "$ts" ] && printf ' at %s;' "$ts")"
} > "$script"

# Body (literal — nothing is expanded at generation time)
cat >> "$script" <<'SCRIPT_BODY'
#
# Writes the .wic.bz2 image that sits next to this script onto an SD card.
# Uses bmaptool (fast, only writes used blocks, verifies checksums) when a
# .bmap is present, otherwise falls back to dd.
#
# Usage:
#   sudo ./flash-sdcard.sh /dev/sdX        flash image (asks to confirm)
#   sudo ./flash-sdcard.sh /dev/sdX -y     skip confirmation prompt
#   ./flash-sdcard.sh                      just list candidate devices
#
# Needs: bmap-tools (recommended) or bunzip2 + dd.
#
#               *** DESTRUCTIVE — the whole device is erased ***

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"

die() { echo "ERROR: $*" >&2; exit 1; }

usage() { sed -n '4,17p' "$0" | sed 's/^# \{0,1\}//'; }

# --- parse arguments ---------------------------------------------------------
YES=0
DEVICE=""
for arg in "$@"; do
    case "$arg" in
        -y|--yes)   YES=1 ;;
        -h|--help)  usage; exit 0 ;;
        -*)         die "unknown option '$arg' (see --help)" ;;
        *)          [ -z "$DEVICE" ] || die "unexpected extra argument '$arg'"
                    DEVICE="$arg" ;;
    esac
done

# --- locate the image --------------------------------------------------------
WIC="$(find "$here" -maxdepth 1 -name '*.wic.bz2' | sort -V | tail -1 || true)"
[ -n "$WIC" ] || die "no *.wic.bz2 found next to this script ($here)"
BMAP="${WIC%.bz2}.bmap"
[ -f "$BMAP" ] || BMAP=""

# --- no device given: list candidates and exit -------------------------------
if [ -z "$DEVICE" ]; then
    echo "No DEVICE given. SD card image: $(basename "$WIC")"
    echo
    echo "Candidate whole-disk devices (RM=1 means removable — usually the SD card):"
    lsblk -dno NAME,SIZE,TYPE,RM,TRAN,VENDOR,MODEL | awk '$3 == "disk"'
    echo
    echo "Now run:  sudo ./flash-sdcard.sh /dev/sdX"
    exit 0
fi

# --- validate target ---------------------------------------------------------
[ -b "$DEVICE" ] || die "'$DEVICE' is not a block device."

dtype="$(lsblk -dno TYPE "$DEVICE" 2>/dev/null || true)"
if [ "$dtype" != "disk" ]; then
    if [ "$dtype" = "part" ]; then
        parent="$(lsblk -dno PKNAME "$DEVICE" 2>/dev/null | head -1 || true)"
        die "'$DEVICE' is a partition — write to the WHOLE device instead (/dev/${parent:-...})."
    fi
    die "'$DEVICE' is not a whole disk (TYPE='$dtype')."
fi

mnt="$(lsblk -rno MOUNTPOINT "$DEVICE" 2>/dev/null | sed '/^$/d' | tr '\n' ' ' || true)"
[ -z "$mnt" ] || die "'$DEVICE' has mounted partitions ($mnt) — unmount first."

dev_bytes="$(lsblk -bno SIZE "$DEVICE")"
img_bytes="$(du -b --apparent-size "$WIC" | cut -f1)"
if [ "${dev_bytes:-0}" -lt "$img_bytes" ]; then
    die "device is smaller than the image ($(numfmt --to=iec "$dev_bytes" 2>/dev/null || echo "$dev_bytes") < $(numfmt --to=iec "$img_bytes" 2>/dev/null || echo "$img_bytes"))."
fi

# --- summary + confirmation --------------------------------------------------
model="$(lsblk -dno VENDOR,MODEL "$DEVICE" 2>/dev/null | xargs)"
size="$(lsblk -dno SIZE "$DEVICE")"
parts="$(lsblk -rno NAME "$DEVICE" 2>/dev/null | tail -n +2 | sed 's|^|/dev/|' | tr '\n' ' ')"

echo "-------------------------------------------------------------------"
echo "  image  : $(basename "$WIC") ($(du -h "$WIC" | cut -f1))"
echo "  bmap   : $([ -n "$BMAP" ] && basename "$BMAP" || echo '<none>')"
echo "  target : $DEVICE${model:+ — $model}${size:+, $size}"
[ -n "$parts" ] && echo "  parts  : $parts — ALL DATA ON THEM WILL BE DESTROYED"
echo "-------------------------------------------------------------------"

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

if [ "$YES" -ne 1 ]; then
    [ -t 0 ] || die "no TTY for confirmation — re-run with -y to accept."
    printf 'Type the device name (e.g. sdb) to confirm overwriting %s: ' "$DEVICE"
    read -r ans
    [ "$ans" = "${DEVICE##*/}" ] || die "aborted — devices do not match."
fi

# --- flash -------------------------------------------------------------------
echo
if command -v bmaptool >/dev/null 2>&1 && [ -n "$BMAP" ]; then
    echo "Flashing with bmaptool (skips unused blocks, verifies checksums) ..."
    $SUDO bmaptool copy --bmap "$BMAP" "$WIC" "$DEVICE"
else
    [ -n "$BMAP" ] && \
        echo "NOTE: .bmap present but bmaptool missing — install it with 'sudo apt install bmap-tools'." >&2
    echo "Flashing with dd (uncompressed stream, can take several minutes) ..."
    bunzip2 -c "$WIC" | $SUDO dd of="$DEVICE" bs=4M status=progress conv=fsync iflag=fullblock
fi

echo "Syncing ..."
sync
echo
echo "Done. $(basename "$WIC") → $DEVICE"
echo "You can now eject the card and boot the board from it."
SCRIPT_BODY

chmod +x "$script"
echo "  Wrote: $script"