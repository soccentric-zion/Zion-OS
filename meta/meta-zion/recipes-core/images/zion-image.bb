SUMMARY = "Zion OS — production image for AMD Xilinx Zynq UltraScale+ MPSoC (KR260)"
DESCRIPTION = "Full image with A/B OTA, gRPC/Protobuf, Zion-HAL, \
               hardware interface tooling, and connectivity."
HOMEPAGE = "https://github.com/SiliconCentric/Zion-OS"
LICENSE = "MIT"

# Base on core-image-full-cmdline (provides bash, sshd-openssh,
# package-management, base IMAGE_INSTALL framework). This is the canonical
# base for all Zion image variants.
require recipes-extended/images/core-image-full-cmdline.bb
IMAGE_FEATURES += "ssh-server-openssh"

# OTA / swupdate
# zion-swupdate-config implements the inactive-slot, boot-selection, and
# rollback flow for sdimage-zynqmp.wks. Install only on the KR260 machine
# (and any future A/B machine).
IMAGE_INSTALL:append:kr260-robotics = " swupdate swupdate-www zion-swupdate-config"

# Home partition init (persistent /home on the data partition)
IMAGE_INSTALL:append = " zion-data-init"

# Root filesystem expansion (single-partition deployments)
IMAGE_INSTALL:append = " expand-rootfs"

# Connectivity
IMAGE_INSTALL:append = " \
    zion-connectivity iw rfkill bluez5-dev \
"

# gRPC + Protobuf via packagegroup-zion-middleware
IMAGE_INSTALL:append = " packagegroup-zion-middleware sudo"

# Cloud/telemetry package group (not installed by default; add via
# packagegroup-zion-cloud when deployments need MQTT/NTP/cloud connectivity)
# IMAGE_INSTALL:append = " packagegroup-zion-cloud"

# Hardware interface tools
IMAGE_INSTALL:append = " \
    i2c-tools python3-smbus python3-smbus2 \
    spitools python3-spidev \
    libgpiod libgpiod-tools python3-gpiod \
    picocom minicom python3-pyserial \
    usbutils pciutils nvme-cli sg3-utils hdparm mtd-utils \
    can-utils \
    lshw ethtool devmem2 cpupower watchdog sysstat iotop strace \
    v4l-utils evtest python3-periphery vim \
"

# Zion stack
IMAGE_INSTALL:append = " zion-hal zion-services"

# Target debugging and profiling
IMAGE_FEATURES += "tools-debug"
IMAGE_INSTALL:append = " gdbserver perf trace-cmd valgrind"

# Ptest package and runner support
IMAGE_FEATURES += "ptest-pkgs"

# Operator account — locked, SSH-key access only
# The data partition (/home) is created by zion-data-init on first boot,
# so use -M (--no-create-home) like the Acadia reference.
inherit extrausers
EXTRA_USERS_PARAMS = "\
    useradd -M -s /bin/bash -G sudo zion; \
    usermod -L zion; \
"
