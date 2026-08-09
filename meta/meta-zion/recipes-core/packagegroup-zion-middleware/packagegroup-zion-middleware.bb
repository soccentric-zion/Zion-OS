SUMMARY = "Zion middleware package group — gRPC, Protobuf, and messaging support"
DESCRIPTION = "Meta-package pulling in the gRPC/Protobuf middleware stack \
used by Zion-HAL and Zion-Client. Add this single package group to \
IMAGE_INSTALL instead of listing individual middleware packages so the set \
stays consistent across every per-industry Zion image."
HOMEPAGE = "https://github.com/SiliconCentric/Zion-OS"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

inherit packagegroup

PACKAGES = "${PN}"
ALLOW_EMPTY:${PN} = "1"

RDEPENDS:${PN} = " \
    protobuf \
    protobuf-lite \
    grpc \
    python3-grpcio \
    python3-protobuf \
"
