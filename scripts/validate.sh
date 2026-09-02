#!/usr/bin/env bash
# validate.sh — static invariants for the Zion-OS build system.
#
# Called by `make validate`. Checks that the pieces the build/OTA flow
# depends on actually line up — the class of bug where a file exists but
# is dead (e.g. a kernel fragment no bbappend references, or an fw_env
# config pointing at storage U-Boot never writes).
#
# Usage: scripts/validate.sh [board]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ZION="${ROOT}/meta/meta-zion"
BOARD="${1:-}"

fails=0
check() {
    # check <description> <condition...>
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  ok    ${desc}"
    else
        echo "  FAIL  ${desc}"
        fails=$((fails + 1))
    fi
}

echo "== Zion-OS validation ${BOARD:+(${BOARD})} =="

# --- layer integrity ---------------------------------------------------------
check "layer.conf has BBFILE_COLLECTIONS"        grep -q "BBFILE_COLLECTIONS += \"meta-zion\"" "${ZION}/conf/layer.conf"
check "LAYERSERIES_COMPAT set"                   grep -q "LAYERSERIES_COMPAT_meta-zion" "${ZION}/conf/layer.conf"
check "layer registered in kas meta-zion.yaml"   grep -q "meta-zion" "${ROOT}/kas/common.yaml"

# --- kas / board config ------------------------------------------------------
check "kas common.yaml exists"                   test -f "${ROOT}/kas/common.yaml"
check "kv260 board config exists"                test -f "${ROOT}/kas/boards/kv260.yaml"
check "kr260 board config exists"                test -f "${ROOT}/kas/boards/kr260.yaml"
check "kv260 declares a machine"                 grep -q "^machine:" "${ROOT}/kas/boards/kv260.yaml"
check "kr260 declares a machine"                 grep -q "^machine:" "${ROOT}/kas/boards/kr260.yaml"
check "meta-zion kas pin is a full/short SHA"    grep -Eq "commit: [0-9a-f]{7,40}" "${ROOT}/kas/repos/meta-zion.yaml"
check "meta-zion pin matches local layer HEAD"   bash -c "cd '${ZION}' && head=\$(git rev-parse HEAD) && grep -q \"commit: \${head:0:7}\" '${ROOT}/kas/repos/meta-zion.yaml'"

# --- image / OTA chain -------------------------------------------------------
check "image recipe exists"                      test -f "${ZION}/recipes-core/images/zion-image.bb"
check "A/B wks has rootfs-a + rootfs-b"          bash -c "grep -q 'rootfs-a' '${ZION}/wic/sdimage-zynqmp.wks' && grep -q 'rootfs-b' '${ZION}/wic/sdimage-zynqmp.wks'"
check "wks has persistent home partition"        grep -q "label=home" "${ZION}/wic/sdimage-zynqmp.wks"
check "sw-description exists"                    test -f "${ZION}/swupdate/sw-description"
check "sw-description targets inactive slot"     grep -q "swupdate-inactive" "${ZION}/swupdate/sw-description"
check "sw-description includes kernel+dtb"       bash -c "grep -q '@@KERNEL@@' '${ZION}/swupdate/sw-description' && grep -q '@@DTB@@' '${ZION}/swupdate/sw-description'"
check "pre/post-install scripts exist"           bash -c "test -f '${ZION}/swupdate/pre-install.sh' && test -f '${ZION}/swupdate/post-install.sh'"
check "boot.cmd.zion has slot marker logic"      bash -c "grep -q 'slot_b' '${ZION}/recipes-bsp/u-boot/u-boot-xlnx-scr/boot.cmd.zion' && grep -q 'upgrade_pending' '${ZION}/recipes-bsp/u-boot/u-boot-xlnx-scr/boot.cmd.zion'"
check "boot.cmd.zion enforces boot counter"      grep -q "bootcount" "${ZION}/recipes-bsp/u-boot/u-boot-xlnx-scr/boot.cmd.zion"
check "u-boot-xlnx-scr bbappend selects zion script" bash -c "grep -q 'BOOTMODE:k26-smk-kv-sdt = \"zion\"' '${ZION}/recipes-bsp/u-boot/u-boot-xlnx-scr.bbappend' && grep -q 'BOOTMODE:k26-smk-kr-sdt = \"zion\"' '${ZION}/recipes-bsp/u-boot/u-boot-xlnx-scr.bbappend'"

# --- U-Boot env / userspace wiring (fw_printenv chain) ------------------------
check "fw_env.config references QSPI env symlinks" bash -c "grep -q '/dev/zion/uboot-env' '${ZION}/recipes-swupdate/zion-swupdate-config/files/fw_env.config'"
check "udev rule maps MTD names to env symlinks"   bash -c "grep -q 'U-Boot storage variables' '${ZION}/recipes-swupdate/zion-swupdate-config/files/60-zion-uboot-env.rules'"
check "recipe installs udev rule"                  grep -q "60-zion-uboot-env.rules" "${ZION}/recipes-swupdate/zion-swupdate-config/zion-swupdate-config.bb"
check "bootcheck writes /boot_ok handshake"        grep -q "boot_ok" "${ZION}/recipes-swupdate/zion-swupdate-config/files/swupdate-bootcheck.sh"

# --- kernel fragment is wired (not a dead file) ------------------------------
check "kernel fragment referenced by a bbappend"  bash -c "grep -rq 'zion-base.cfg' '${ZION}/recipes-kernel/linux/'*.bbappend"
check "kernel fragment has CONFIG_ lines"         grep -q "^CONFIG_" "${ZION}/recipes-kernel/linux/files/zion-base.cfg"

# --- swupdate signing --------------------------------------------------------
check "SIGNED_IMAGES enabled in swupdate bbappend" grep -q "CONFIG_SIGNED_IMAGES=y" "${ZION}/recipes-support/swupdate/files/zion-signing.cfg"
check "swupdate-start validates public key"        grep -q "openssl pkey -pubin" "${ZION}/recipes-swupdate/zion-swupdate-config/files/swupdate-start.sh"
check "committed public key parses as PEM pub"     bash -c "openssl pkey -pubin -in '${ZION}/recipes-swupdate/zion-swupdate-config/files/swupdate-public.pem' -noout"
check "private key (if present) is outside recipes" bash -c "[ ! -e '${ZION}/recipes-swupdate/zion-swupdate-config/files/swupdate-private.pem' ]"
check "Makefile signs when private key exists"     grep -q "swupdate-private.pem" "${ROOT}/Makefile"

# --- security invariants ------------------------------------------------------
check "image does not set a root password"        bash -c "! grep -Eq 'passwd[ -]root|root:.*\$\$' \"${ZION}/recipes-core/images/zion-image.bb\""
check "openssh drop-in disables root login"        grep -q "PermitRootLogin no" "${ZION}/recipes-connectivity/openssh/files/50-zion.conf"
check "openssh bbappend exists"                    test -f "${ZION}/recipes-connectivity/openssh/openssh_%.bbappend"
check "operator user documented (zion)"            grep -q "useradd.*zion" "${ZION}/recipes-core/images/zion-image.bb"

# --- docker / scripts ---------------------------------------------------------
check "docker/yocto Dockerfile exists"             test -f "${ROOT}/docker/yocto/Dockerfile"
check "docker/sdk Dockerfile exists"               test -f "${ROOT}/docker/sdk/Dockerfile"
check "docker/esdk Dockerfile exists"              test -f "${ROOT}/docker/esdk/Dockerfile"
check "kas-container script present"               test -f "${ROOT}/kas-container"
check "generate-swu-keys.sh present"               test -f "${ROOT}/scripts/generate-swu-keys.sh"
check "CI workflow present"                        test -f "${ROOT}/.github/workflows/ci.yml"

echo
if [ "${fails}" -eq 0 ]; then
    echo "ALL CHECKS PASSED"
else
    echo "${fails} CHECK(S) FAILED"
    exit 1
fi