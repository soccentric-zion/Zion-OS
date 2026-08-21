# Zion-OS

## Project Summary

Preserve downloads and sstate caches when comparing build reproducibility across hosts.

Image metadata, layer pins, and scripts can be reviewed offline, but bootloader behavior, partition selection, update recovery, and hardware peripherals all require a target board and a deliberately staged test image.

Zion-OS is a Yocto-based embedded Linux distribution for AMD Xilinx Zynq UltraScale+ MPSoC hardware. The repository uses kas configurations and a Docker build environment to assemble a board image, SDK/eSDK artifacts, and a swupdate package. Its documented default target is the KR260 Robotics Starter Kit, represented by `kas/boards/kr260.yaml`; shared settings live in `kas/common.yaml`, while repository pins select the Xilinx `rel-v2025.2` layer set. The custom meta layer supplies Zion image, HAL, Client, and update integration. The documented boot path runs from SD/QSPI through FSBL, firmware, ATF, U-Boot, Linux, systemd, Zion-HAL, and Zion-Client. The image layout describes boot, rootfs A/B, and persistent data partitions, with swupdate updating the inactive root filesystem and a health-check service confirming a successful boot. The Makefile provides image, rebuild, SDK, eSDK, shell, swu, flash, kas-image, clean, and Docker-image workflows. The repository also contains build/cache directories, so a clean reproducible build may require deliberate cache handling and substantial disk space. This README retains the operational guidance but treats build outputs, signing, flashing, boot, rollback, and recovery as unverified until exercised on a KR260 or actual Zion board. The table distinguishes source-controlled configuration from hardware-dependent behavior and names commands that can provide evidence. Cross-compiling Zion-HAL and Zion-Client against the generated SDK is an intended integration path, not a claim that those sibling builds currently pass together.

## Feature Status

| # | Name / Description | Implemented? | Test Coverage? | Manual Test |
|---:|---|---|---|---|
| 1 | kas workspace and pinned Yocto layer set | Implemented | Parse/build not run | [ ] Manual verification required |
| 2 | KR260 machine configuration | Implemented | Image build not verified | [ ] Manual verification required |
| 3 | Dockerized kas build environment | Implemented | Container build not verified | [ ] Manual verification required |
| 4 | Bootable SD/QSPI image generation | Partial | Build evidence not run | [ ] Manual verification required |
| 5 | Zion custom Yocto layer integration | Implemented | BitBake validation unknown | [ ] Manual verification required |
| 6 | A/B rootfs partition layout | Implemented | Target boot/rollback unverified | [ ] Manual verification required |
| 7 | swupdate `.swu` package generation | Implemented | `make swu` not run | [ ] Manual verification required |
| 8 | Update signing key workflow | Partial | Key/signature verification unknown | [ ] Manual verification required |
| 9 | Health-check slot confirmation | Partial | Device boot test absent | [ ] Manual verification required |
| 10 | SDK and eSDK generation | Implemented | Toolchain build not run | [ ] Manual verification required |
| 11 | SD flashing with bmaptool | Implemented | Destructive flash not performed | [ ] Manual verification required |
| 12 | KR260 boot and recovery procedure | Documented | No physical test | [ ] Manual verification required |

## Tests and Commands

```bash
make kas-image
make image kr260
make swu
make sdk kr260
make esdk kr260
```

Use `make flash kr260 DEVICE=/dev/sdX` only after independently identifying the target device.

## Limitations

No Yocto build, signed update, SD flash, KR260 boot, A/B rollback, recovery, or SDK consumer build was manually verified. Board support beyond the documented KR260 target remains unconfirmed.
# Zion-OS

Yocto-based embedded Linux OS for the AMD Xilinx Zynq UltraScale+ MPSoC platform.
Default target board: **KR260** (Kria KR260 Robotics Starter Kit).

Built with [kas](https://kas.readthedocs.io/) against the Xilinx `rel-v2025.2` layer set.
Supports A/B OTA updates via [swupdate](https://sbabic.github.io/swupdate/).

---

## Table of Contents

- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Boards](#boards)
- [Build Targets](#build-targets)
- [OTA Update (.swu)](#ota-update-swu)
- [Flash to SD Card](#flash-to-sd-card)
- [KR260 Boot & Flash Instructions](#kr260-boot--flash-instructions)
- [SDK / eSDK](#sdk--esdk)
- [Layer Structure](#layer-structure)
- [Adding a New Board](#adding-a-new-board)

---

## Architecture

```
Zion-OS
├── kas/
│   ├── common.yaml          # Shared Yocto config (distro, image, caches)
│   ├── boards/
│   │   └── kr260.yaml       # KR260 machine config (default)
│   └── repos/
│       ├── poky.yaml              # Xilinx fork of poky (rel-v2025.2)
│       ├── meta-openembedded.yaml # Xilinx fork of OE (rel-v2025.2)
│       ├── meta-xilinx.yaml       # Zynq UltraScale+ BSP
│       ├── meta-xilinx-tools.yaml # Xilinx build tools (bootgen, FSBL, etc.)
│       ├── meta-kria.yaml         # Kria SOM / KR260 machine configs
│       ├── meta-swupdate.yaml     # swupdate OTA framework
│       └── meta-zion.yaml        # Custom Zion layer (image recipe, HAL, Client)
├── docker/
│   ├── yocto/     # kas build container (zion-kas)
│   ├── sdk/       # Yocto cross-toolchain SDK container (zion-sdk)
│   └── esdk/      # Yocto extensible SDK container (zion-esdk)
└── Makefile       # Top-level build orchestration
```

**Boot flow on KR260:**
```
SD/QSPI → FSBL (First Stage Boot Loader)
        → PMU Firmware
        → ATF (Arm Trusted Firmware / TF-A)
        → U-Boot
        → Linux (Image + zynqmp-smk-k26-revA-sck-kr-g-revB.dtb)
        → systemd → Zion-HAL, Zion-Client
```

**A/B OTA layout:**
```
Partition table (sdimage-zynqmp.wks in meta-zion):
  boot       FAT32   BOOT.BIN + Image + DTB
  rootfsA    ext4    slot A (active after initial flash)
  rootfsB    ext4    slot B (updated by swupdate, then activated)
  data       ext4    /var/lib/zion — persistent, never touched by OTA
```

---

## Prerequisites

### Host packages

```bash
# Ubuntu 22.04 / 24.04
sudo apt-get install -y \
    docker.io curl git make \
    bmap-tools   # for 'make flash'
```

Docker must be runnable without `sudo`. Add your user to the `docker` group and re-login if needed:

```bash
sudo usermod -aG docker $USER
```

### kas-container

Downloaded automatically on first build. Requires `curl` and Docker.

---

## Quick Start

```bash
# 1. Clone
git clone git@github.com:soccentric-zion/Zion-OS.git
cd Zion-OS

# 2. Build the KAS Docker image (once)
make kas-image

# 3. Build the Yocto image for KR260 (default board)
make image

# Build artifacts land in:
#   deploy/images/kr260_<timestamp>/  ← .wic.bz2 + .wic.bmap
```

Tab completion (optional):

```bash
make completion    # adds source line to ~/.bashrc
source ~/.bashrc
```

---

## Boards

| Board name | MACHINE           | SoC                          |
|------------|-------------------|------------------------------|
| `kr260`    | `kr260-robotics`  | Zynq UltraScale+ XCZU5EV     |

Add more boards by creating `kas/boards/<name>.yaml` (see [Adding a New Board](#adding-a-new-board)).

---

## Build Targets

```
make image  kr260          Build Yocto SD card image (default board: kr260)
make build  kr260          Alias for image
make rebuild-image kr260   cleansstate image recipe, then rebuild
make sdk    kr260          Cross-toolchain SDK installer → deploy/sdk/
make esdk   kr260          Extensible SDK installer     → deploy/esdk/
make shell  kr260          Interactive kas shell in the build container
make swu                   Build .swu OTA package       → deploy/swu/
make flash  kr260 DEVICE=/dev/sdX   Flash image to SD card

# Override image version for OTA package:
make swu SWU_VERSION=1.2.3

# Docker image management:
make kas-image             Build/rebuild KAS build container
make sdk-image             Full chain: SDK build → Docker image
make esdk-image            Full chain: eSDK build → Docker image

# Clean:
make clean                 Remove build/
make clean-all             Remove build/, downloads/, sstate-cache/
make clean-docker          Remove kas/sdk/esdk Docker images
```

---

## OTA Update (.swu)

```bash
make swu
# → build/<BOARD>-<VERSION>.swu
# → deploy/swu/<BOARD>_<TIMESTAMP>/<BOARD>-<VERSION>.swu
```

The `.swu` contains:
- `rootfs.ext4.gz` — compressed root filesystem for the inactive slot
- `Image` — kernel
- `zynqmp-smk-k26-revA-sck-kr-g-revB.dtb` — device tree blob
- `sw-description` — swupdate manifest (see `meta/meta-zion/swupdate/sw-description`)

**Signing:** If `meta/meta-zion/swupdate/keys/swupdate-private.pem` is present, the `.swu` is RSA-4096 signed. Generate keys with `scripts/generate-swu-keys.sh`.

**Apply OTA on device:**

```bash
# via swupdate web UI (port 8080) or CLI:
swupdate -i /path/to/kr260-<version>.swu
```

After a successful update, U-Boot boots the new slot. The health-check service
(`zion-health-check.service`) marks the slot confirmed by calling `fw_setenv upgrade_available 0`.

---

## Flash to SD Card

```bash
make flash kr260 DEVICE=/dev/sdX
# Uses bmaptool for fast, verified write.
```

**Identify your SD card device first:**

```bash
lsblk -d -o NAME,SIZE,MODEL
```

---

## KR260 Boot & Flash Instructions

### Initial SD card setup

1. Build the image: `make image kr260`
2. Flash: `make flash kr260 DEVICE=/dev/sdX`
3. Insert the SD card into the KR260 microSD slot.
4. Set the boot mode jumper on KR260 to SD card boot (SW1: `1100` — check the KR260 Rev1 board user guide).
5. Connect a USB-UART cable to the KR260 UART0/USB port (J4).
6. Open a serial terminal at **115200 8N1** (e.g. `minicom -D /dev/ttyUSB1 -b 115200`).
7. Power on; U-Boot and Linux boot messages appear on UART0.
8. Default login: configured by `meta-zion` (key-based SSH only; see layer README).

### QSPI boot (production)

BOOT.BIN (FSBL + PMU FW + ATF + U-Boot) can be programmed to QSPI flash for
standalone board boot without an SD card. Use `xsct` or `program_flash` from
Vitis/PetaLinux. Rootfs A/B and the data partition remain on eMMC or SD.

### Recovery (bricked board)

1. Connect JTAG via the KR260 JTAG/USB port.
2. Boot a known-good image from SD card using the SD boot mode override.
3. Or use `xsct` to directly load and run U-Boot over JTAG, then re-flash.

---

## SDK / eSDK

```bash
# Build cross-toolchain SDK (no Docker image):
make sdk kr260
# → deploy/sdk/kr260_<timestamp>/*.sh

# Build SDK + Docker image (for CI cross-compilation containers):
make sdk-image

# Build extensible SDK + Docker image:
make esdk-image
```

Use the SDK Docker image (`zion-sdk:latest`) to cross-compile Zion-HAL and Zion-Client
against the exact sysroot the image was built with.

---

## Layer Structure

| Layer               | Source                                    | Purpose                              |
|---------------------|-------------------------------------------|--------------------------------------|
| `meta`              | Xilinx/poky (rel-v2025.2)                 | OE core                              |
| `meta-poky`         | Xilinx/poky (rel-v2025.2)                 | Poky distro policy                   |
| `meta-oe`           | Xilinx/meta-openembedded (rel-v2025.2)    | Broad package set                    |
| `meta-python`       | Xilinx/meta-openembedded (rel-v2025.2)    | Python packages                      |
| `meta-networking`   | Xilinx/meta-openembedded (rel-v2025.2)    | Network utilities                    |
| `meta-multimedia`   | Xilinx/meta-openembedded (rel-v2025.2)    | Multimedia (optional)                |
| `meta-xilinx-core`  | Xilinx/meta-xilinx (rel-v2025.2)          | ZynqMP BSP, kernel, U-Boot, ATF      |
| `meta-xilinx-standalone` | Xilinx/meta-xilinx (rel-v2025.2)    | Bare-metal / FSBL recipes            |
| `meta-xilinx-tools` | Xilinx/meta-xilinx-tools (rel-v2025.2)    | bootgen, XSCT, Vitis integration     |
| `meta-kria`         | Xilinx/meta-kria (rel-v2025.2)            | Kria SOM + KR260 machine configs     |
| `meta-swupdate`     | sbabic/meta-swupdate (scarthgap)          | swupdate OTA framework               |
| `meta-zion`         | soccentric-zion/meta-zion (rel-v2025.2)    | Zion image, HAL, Client, swu config  |

---

## Adding a New Board

1. Create `kas/boards/<board-name>.yaml`:

```yaml
header:
  version: 14
  includes:
    - ../common.yaml

machine: <yocto-machine-name>    # from meta-kria or meta-xilinx-core

local_conf_header:
  wks: |
    WKS_FILE = "sdimage-zynqmp.wks"
```

2. Verify the machine name exists in `meta-kria` or `meta-xilinx-core`.

3. Build: `make image <board-name>`

---

## Changelog

### Zion-OS (initial — ported from Acadia-OS)

- **Platform:** Raspberry Pi → AMD Xilinx Zynq UltraScale+ MPSoC (KR260)
- **BSP layer:** `meta-raspberrypi` → `meta-xilinx` + `meta-xilinx-tools` + `meta-kria`
- **poky source:** upstream → Xilinx fork (`rel-v2025.2`)
- **meta-openembedded source:** upstream → Xilinx fork (`rel-v2025.2`)
- **Custom layer:** `meta-acadia` → `meta-zion`
- **Image recipe:** `acadia-image` → `zion-image`
- **Default board:** `rpi5` → `kr260` (machine: `kr260-robotics`)
- **Docker images:** `rpi5-kas`, `rpi5-sdk`, `rpi5-esdk` → `zion-kas`, `zion-sdk`, `zion-esdk`
- **Kernel image:** `kernel_2712.img` (RPi5-specific) → `Image` (standard arm64)
- **DTB:** `bcm2712-rpi-5-b.dtb` → `zynqmp-smk-k26-revA-sck-kr-g-revB.dtb`
- **U-Boot env tool:** `u-boot-fw-utils` → `libubootenv-bin`
- **Removed:** RPi-specific vars (`GPU_MEM`, `ENABLE_UART`, `RPI_USE_U_BOOT`, `rpi_arm64_defconfig`, `synaptics-killswitch` licence)
- **Removed:** All RPi board configs (rpi0–rpi5, cm1–cm5, rpi-armv7, rpi-armv8)
- **Removed:** `patch_health.py` (Acadia-Server specific)
- **Renamed:** `rpi-make-completion.bash` → `zion-make-completion.bash`
- **Updated:** `config` (HAL repository URL: Acadia-HAL → Zion-HAL)
- **Updated:** `req.md` (audit prompt: Acadia-OS → Zion-OS, RPi → KR260)
- **swupdate OTA:** A/B dual-rootfs structure preserved; sw-description path updated to `meta/meta-zion/swupdate/sw-description`
- **Boot flow:** RPi GPU-based boot (config.txt) → Zynq FSBL → PMU FW → ATF → U-Boot → Linux
