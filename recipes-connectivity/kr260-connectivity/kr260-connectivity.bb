SUMMARY = "KR260 connectivity — DHCP on GigE (systemd-networkd)"
DESCRIPTION = "Provides systemd-networkd network files and a systemd preset \
for automatic DHCP on Ethernet interfaces. \
The KR260 carrier board has one GigE port; no on-board WiFi or Bluetooth."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://10-eth.network \
    file://10-eth-vlan10.netdev \
    file://11-eth-vlan10.network \
    file://80-kr260-connectivity.preset \
"

inherit systemd

SYSTEMD_SERVICE:${PN} = ""

# runtime requirement: the images should already include systemd-networkd,
# but declare it here for clarity.
RDEPENDS:${PN} = "systemd"

NETWORKD_DIR = "${sysconfdir}/systemd/network"
PRESET_DIR   = "${sysconfdir}/systemd/system-preset"

do_install() {
    install -d ${D}${NETWORKD_DIR}
    install -m 0644 ${WORKDIR}/10-eth.network          ${D}${NETWORKD_DIR}/
    install -m 0644 ${WORKDIR}/10-eth-vlan10.netdev    ${D}${NETWORKD_DIR}/
    install -m 0644 ${WORKDIR}/11-eth-vlan10.network   ${D}${NETWORKD_DIR}/

    install -d ${D}${PRESET_DIR}
    install -m 0644 ${WORKDIR}/80-kr260-connectivity.preset \
                    ${D}${PRESET_DIR}/80-kr260-connectivity.preset
}

FILES:${PN} += " \
    ${NETWORKD_DIR} \
    ${PRESET_DIR} \
"
