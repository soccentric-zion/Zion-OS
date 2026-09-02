#!/usr/bin/env bash
# check-board.sh — validate a board configuration for the Zion build.
#
# Called by `make check-board [BOARD]`. Verifies the kas board yaml exists,
# declares a MACHINE, and that the machine is registered in a layer this
# build can actually resolve (BBLAYERS machine conf search).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOARD="${1:-}"

fail() { echo "ERROR: $*" >&2; exit 1; }

# --- discover boards ----------------------------------------------------------
if [ -z "${BOARD}" ]; then
    echo "Supported boards:"
    for f in "${ROOT}"/kas/boards/*.yaml; do
        b="$(basename "$f" .yaml)"
        m="$(grep '^machine:' "$f" | awk '{print $2}')"
        printf '  %-10s MACHINE=%s\n' "$b" "${m:-<unset>}"
    done
    exit 0
fi

cfg="${ROOT}/kas/boards/${BOARD}.yaml"
[ -f "$cfg" ] || fail "no board config at kas/boards/${BOARD}.yaml (see kas/boards/)"

machine="$(grep '^machine:' "$cfg" | awk '{print $2}')"
[ -n "$machine" ] || fail "${BOARD}.yaml does not declare a 'machine:'"
echo "board   : ${BOARD}"
echo "machine : ${machine}"

# --- machine config must exist in a layer on disk -----------------------------
machine_conf="$(find "${ROOT}/layers" "${ROOT}/meta" -name "${machine}.conf" -path "*conf/machine/*" 2>/dev/null | head -1)"
if [ -z "${machine_conf}" ]; then
    fail "machine config ${machine}.conf not found in layers/ or meta/ — run 'make build' once (kas clones layers) or fix the MACHINE name"
fi
echo "conf    : ${machine_conf#${ROOT}/}"

# --- kas yaml must parse ------------------------------------------------------
python3 - "$cfg" "$ROOT/kas/common.yaml" "$ROOT/kas/repos/meta-zion.yaml" <<'EOF'
import sys
try:
    import yaml
except ImportError:
    print("  (pyyaml unavailable — skipping YAML parse check)")
    sys.exit(0)
for f in sys.argv[1:]:
    with open(f) as fh:
        yaml.safe_load(fh)
    print(f"  ok    {f} parses as YAML")
EOF

echo "check-board: OK"