SUMMARY = "KR260 home partition initialisation"
DESCRIPTION = "One-shot systemd service that initialises /home/zion on the \
persistent ext4 data partition (p4) on first boot, then expands the partition \
to fill any remaining SD card space."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://kr260-home-init.sh \
    file://kr260-home-init.service \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = "kr260-home-init.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} = "bash util-linux parted e2fsprogs-resize2fs"

do_install() {
    install -d ${D}${libdir}/kr260-home-init
    install -m 0755 ${WORKDIR}/kr260-home-init.sh \
                    ${D}${libdir}/kr260-home-init/kr260-home-init.sh

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/kr260-home-init.service \
                    ${D}${systemd_system_unitdir}/kr260-home-init.service
}

FILES:${PN} += " \
    ${libdir}/kr260-home-init \
    ${systemd_system_unitdir}/kr260-home-init.service \
"
