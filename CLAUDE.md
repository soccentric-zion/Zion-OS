# Zion-OS — Yocto embedded Linux for AMD Xilinx Zynq UltraScale+ MPSoC

## Overview

Zion-OS is the Yocto/OpenEmbedded build system for the **Zion** platform — the
AMD Xilinx **Zynq UltraScale+ MPSoC** (quad-core Cortex-A53 @ 1.5 GHz PS +
dual-core Cortex-R5 + PL fabric). Default board: **KV260** (Kria KV260 Vision AI
Starter Kit). Built with [kas](https://kas.readthedocs.io/) + Docker against the
Xilinx `rel-v2025.2` layer set, with A/B OTA updates via
[swupdate](https://sbabic.github.io/swupdate/).

## Quick Start

```bash
# 1. Build the KAS Docker image (once)
make kas-image

# 2. Build the Yocto image for KV260 (default board)
make image kv260

# 3. Tab completion (optional)
make completion && source ~/.bashrc
```

## Build Targets

```
make image  kr260          Build Yocto SD card image (default: kr260)
make build  kr260          Alias for image
make rebuild-image kr260   cleansstate image recipe, then rebuild
make sdk    kr260          Cross-toolchain SDK installer → deploy/sdk/
make esdk   kr260          Extensible SDK installer     → deploy/esdk/
make shell  kr260          Interactive kas shell in the build container
make swu                   Build .swu OTA package       → deploy/swu/
make flash  kr260 DEVICE=/dev/sdX   Flash image to SD card
```

## Boot Flow (KR260)

```
SD/QSPI → FSBL → PMU Firmware → ATF (TF-A) → U-Boot → Linux → systemd
        → Zion-HAL, Zion services
```

## A/B OTA Layout

Partition table (`meta/meta-zion/meta/meta-zion/wic/sdimage-zynqmp.wks`):
```
  boot       FAT32   BOOT.BIN + Image + DTB + extlinux
  rootfs-a   ext4    slot A (active after initial flash)
  rootfs-b   ext4    slot B (updated by swupdate, then activated)
  data       ext4    /home — persistent, never touched by OTA
```

`make swu` builds an `.swu` package. Signing via
`scripts/generate-swu-keys.sh` (RSA-4096).

## Layer Structure

| Layer               | Source                            | Purpose                              |
|---------------------|-----------------------------------|--------------------------------------|
| `poky`              | Xilinx/poky (rel-v2025.2)         | OE core                              |
| `meta-oe`           | Xilinx/meta-openembedded (rel-v2025.2) | Package set                     |
| `meta-xilinx-core`  | Xilinx/meta-xilinx (rel-v2025.2)  | ZynqMP BSP, kernel, U-Boot, ATF      |
| `meta-xilinx-tools` | Xilinx/meta-xilinx-tools (rel-v2025.2) | bootgen, XSCT, Vitis           |
| `meta-kria`         | Xilinx/meta-kria (rel-v2025.2)    | Kria SOM + KR260 machine configs     |
| `meta-swupdate`     | sbabic/meta-swupdate (scarthgap)  | swupdate OTA framework               |
| `meta-zion`         | soccentric-zion/meta-zion (local, in `meta/`) | Zion image, HAL, swu config |

## Repo Notes

- `build/`, `downloads/`, `sstate-cache/`, `layers/` are gitignored
  bind-mounted host dirs.
- `meta/meta-zion` is committed **locally** in this repo (see `.gitignore`);
  upstream layers are cloned by kas into `layers/` and must never be
  hand-edited.
- `config` holds the Zion-HAL repository URL (used by the HAL recipe).

## Hardware Interface Tools

The image ships I2C, SPI, GPIO (libgpiod), UART, USB, PCIe/NVMe, CAN, video,
and sensor tooling — see `meta/meta-zion/recipes-core/images/zion-image.bb`.
