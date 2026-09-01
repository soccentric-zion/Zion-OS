#!/usr/bin/env bash
# generate-install-ota.sh — write a self-contained OTA installer helper into
# a .swu deploy directory.
#
# Called automatically by `make deploy-swu` right after the .swu package is
# copied, so every deploy/swu/BOARD_TS/ folder ships with its own installer
# script and stays usable on any host without the Zion-OS repo.
#
# The generated install-ota.sh does NOT flash the .swu itself (SWUpdate runs
# on the device); it gets the package to the device in the three usual ways:
# HTTP serve (web UI / curl), SSH push, or copy to a mounted SD/USB stick.
#
# Usage:
#   scripts/generate-install-ota.sh <outdir> [<board>] [<swu-version>]

set -euo pipefail

out="${1:?usage: generate-install-ota.sh <outdir> [<board>] [<swu-version>]}"
board="${2:-}"
version="${3:-}"

mkdir -p "$out"
script="$out/install-ota.sh"

# Header (interpolated: board/version stamped in) ...
{
    printf '#!/usr/bin/env bash\n'
    printf '# install-ota.sh — Zion-OS%s OTA package installer helper\n' \
        "$([ -n "$board" ] && printf ' %s' "$board")"
    if [ -n "$version" ]; then
        printf '# For %s-%s.swu; auto-generated from the Zion-OS build — do not edit.\n' \
            "$board" "$version"
    else
        printf '# Auto-generated from the Zion-OS build — do not edit.\n'
    fi
} > "$script"

# Body (literal — nothing is expanded at generation time)
cat >> "$script" <<'SCRIPT_BODY'
#
# SWUpdate applies .swu packages ON the device — this script gets the package
# sitting next to it there, any of three ways:
#
#   ./install-ota.sh --serve [PORT]     host this folder over HTTP; upload via
#                                       the device web UI or download+install
#   ./install-ota.sh --device <ip>      scp to a running device and install
#   ./install-ota.sh --copy   <dir>     copy to a mounted SD/USB stick
#
# Environment overrides:
#   SWUPDATE_SSH_USER      ssh user on the device   (default: root)
#   SWUPDATE_REMOTE_DIR    staging directory        (default: /data/updates)
#   SWUPDATE_INSTALL_CMD   on-device install cmd    (default: swupdate -i <file>)
#
# The device also runs the SWUpdate web UI on port 8080 — you can always
# upload .swu packages there directly: http://<device-ip>:8080

set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
die() { echo "ERROR: $*" >&2; exit 1; }

SWU="$(find "$here" -maxdepth 1 -name '*.swu' | sort -V | tail -1 || true)"
[ -n "$SWU" ] || die "no *.swu package found next to this script ($here)"
SWU_NAME="$(basename "$SWU")"

show_info() {
    echo "OTA package : $SWU_NAME ($(du -h "$SWU" | cut -f1))"
    if command -v sha256sum >/dev/null 2>&1; then
        echo "SHA-256     : $(sha256sum "$SWU" | cut -d' ' -f1)"
    fi
    if command -v cpio >/dev/null 2>&1 && \
       cpio -it -F "$SWU" 2>/dev/null | grep -qx 'sw-description.sig'; then
        echo "Signed      : yes (RSA — verified against the device key)"
    else
        echo "Signed      : NO — a device enforcing RSA/signed-images will reject it;"
        echo "              sign the build with scripts/generate-swu-keys.sh and rebuild."
    fi
    echo
    echo "Usage: $0 --serve [PORT]"
    echo "       $0 --device <ip-or-hostname>"
    echo "       $0 --copy   <mounted-dir>"
}

# --- --copy: place the .swu on a mounted stick/card ---------------------------
mode_copy() {
    dst="${1:?}"
    [ -d "$dst" ] || die "'$dst' is not a directory — mount the stick/card first."
    [ -w "$dst" ] || die "no write permission on '$dst'."
    cp -v "$SWU" "$dst/"
    echo
    echo "Copied. On the device, install it via the web UI (http://<device-ip>:8080)"
    echo "or from the shell, wherever that volume is mounted, e.g.:"
    echo "  swupdate -i /run/media/root/<volume>/$SWU_NAME"
}

# --- --serve: host this folder over HTTP --------------------------------------
mode_serve() {
    port="${1:-8080}"
    command -v python3 >/dev/null 2>&1 || die "python3 not found (required for --serve)."
    ip="$(hostname -I 2>/dev/null | awk '{print $1}')"
    echo "Serving $here on 0.0.0.0:$port ..."
    echo
    echo "On the device, either open the SWUpdate web UI and upload:"
    echo "    package URL : http://${ip}:${port}/${SWU_NAME}"
    echo "...or install from the device shell:"
    echo "    curl -fL -o /tmp/${SWU_NAME} http://${ip}:${port}/${SWU_NAME} \\"
    echo "      && swupdate -i /tmp/${SWU_NAME}"
    echo
    echo "Press Ctrl-C to stop the server."
    exec python3 -m http.server "$port" --bind 0.0.0.0 --directory "$here"
}

# --- --device: push over SSH and install ---------------------------------------
mode_device() {
    ip="${1:?}"
    user="${SWUPDATE_SSH_USER:-root}"
    rdir="${SWUPDATE_REMOTE_DIR:-/data/updates}"
    remote="$rdir/$SWU_NAME"
    cmd="${SWUPDATE_INSTALL_CMD:-swupdate -i $remote}"

    echo "Pushing $SWU_NAME → $user@$ip:$remote ..."
    ssh "$user@$ip" "mkdir -p '$rdir'"
    scp -p "$SWU" "$user@$ip:$remote"

    if command -v sha256sum >/dev/null 2>&1; then
        want="$(sha256sum "$SWU" | cut -d' ' -f1)"
        got="$(ssh "$user@$ip" "sha256sum '$remote' 2>/dev/null | cut -d' ' -f1")"
        [ "$got" = "$want" ] || die "SHA-256 mismatch after transfer (got '$got', want '$want')."
        echo "SHA-256 verified on device OK"
    fi

    echo "Installing on device: $cmd"
    ssh -t "$user@$ip" "$cmd"
    echo
    echo "Update running — the device reboots into the new slot afterwards."
    echo "Watch the serial console; boot-watchdog auto-rolls back if it fails to boot."
}

# --- main ----------------------------------------------------------------------
mode="${1:---help}"
case "$mode" in
    info)          show_info ;;
    -h|--help|"")  show_info ;;
    --serve)       shift; mode_serve "${1:-8080}" ;;
    --copy)        [ $# -ge 2 ] || die "--copy needs a mounted directory"; shift; mode_copy "$1" ;;
    --device)      [ $# -ge 2 ] || die "--device needs an IP/hostname"; shift; mode_device "$1" ;;
    *)             die "unknown option '$mode' — run with --help" ;;
esac
SCRIPT_BODY

chmod +x "$script"
echo "  Wrote: $script"