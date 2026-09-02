# Zion-OS

## Project Summary

Zion-OS is a Yocto-based embedded Linux distribution for the AMD Xilinx
Zynq UltraScale+ MPSoC (Kria KV260 Vision AI / KR260 Robotics Starter Kits).
The build runs in a Dockerized kas environment against the Xilinx
`rel-v2025.2` layer set, and produces a bootable SD-card image, SDK/eSDK
installers, and a signed `.swu` OTA package.

**Build status:** the complete image build is verified —
`make image kv260` / `make image kr260` produce flashable images
(`deploy/images/<board>_<timestamp>/`, with `.wic.bz2`, `.wic.bmap`, a
self-contained flash script and a build manifest), `make swu` produces the
signed OTA package, and `make validate` checks the OTA/signing/security
chain in CI (`.github/workflows/ci.yml`). Boot/OTA behavior on real silicon
still requires a staged hardware test, but every build-stage artifact path
is exercised by the build itself.

## Feature Status

| # | Name / Description | Implemented? | Verified by |
|---:|---|---|---|
| 1 | kas workspace and pinned Yocto layer set | Implemented | `make lint` / `make validate` |
| 2 | KV260 + KR260 machine configuration | Implemented | `make check-board`, image builds |
| 3 | Dockerized kas build environment | Implemented | `make kas-image`, `make test` |
| 4 | Bootable SD image generation (A/B layout) | Implemented | `make image kv260` / `kr260` |
| 5 | Zion custom layer (image, HAL, services) | Implemented | build + rootfs content |
| 6 | A/B rootfs slots + persistent /home | Implemented | `sdimage-zynqmp.wks` |
| 7 | swupdate `.swu` generation | Implemented | `make swu` |
| 8 | RSA-4096 signed updates (key generated, public baked in) | Implemented | `scripts/validate.sh` |
| 9 | Health-check slot confirmation + rollback | Implemented | `swupdate-bootcheck` / `boot-watchdog` / `boot.cmd.zion` |
| 10 | U-Boot env (fw_printenv) in redundant QSPI storage | Implemented | `fw_env.config` + udev symlinks |
| 11 | SDK / eSDK generation | Implemented | `make sdk` / `make esdk` |
| 12 | SD flashing with bmaptool | Implemented | `make flash`, per-deploy flash script |
| 13 | KV260/KR260 hardware enablement (VCU, GPU, FPGA overlays, RPU/OpenAMP, sensors, CAN, NVMe, TRNG) | Implemented | kernel fragment + image recipes |
| 14 | QSPI boot-firmware A/B update on device | Implemented | `xmutil updateboot` (BOOT.BIN in /boot) |
| 15 | CI builds both boards + exports artifacts | Implemented | `.github/workflows/ci.yml` |

Board boot, SD flash, OTA rollback and recovery are hardware-verified
procedures documented below; they require a physical board by definition.

## Tests and Commands

```bash
make lint          # Makefile + kas YAML sanity
make test          # host prerequisites (docker, curl, openssl, ...)
make check-board   # board config validation (kv260, kr260)
make validate      # OTA/signing/security invariants (scripts/validate.sh)

make kas-image
make image kv260   # full image build (also: make image kr260)
make swu           # signed OTA package
make sdk kv260
make esdk kv260
```

Use `make flash kv260 DEVICE=/dev/sdX` only after independently identifying
the target device. The remaining sections retain the full operational guide.

## Detailed Reference

The retained Yocto guide below contains the repository's extended architecture, board, build, update, and flashing notes.
# Zion-OS

Yocto-based embedded Linux OS for the AMD Xilinx Zynq UltraScale+ MPSoC platform.
Default target board: **KV260** (Kria KV260 Vision AI Starter Kit).

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
- [KV260 Boot & Flash Instructions](#kv260-boot--flash-instructions)
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
│   │   ├── kv260.yaml      # KV260 machine config (default)
│   │   └── kr260.yaml      # KR260 machine config
│   └── repos/
│       ├── poky.yaml              # Xilinx fork of poky (rel-v2025.2)
│       ├── meta-openembedded.yaml # Xilinx fork of OE (rel-v2025.2)
│       ├── meta-xilinx.yaml       # Zynq UltraScale+ BSP
│       ├── meta-xilinx-tools.yaml # Xilinx build tools (bootgen, FSBL, etc.)
│       ├── meta-kria.yaml         # Kria SOM / KV260 & KR260 machine configs
│       ├── meta-swupdate.yaml     # swupdate OTA framework
│       └── meta-zion.yaml        # Custom Zion layer (image recipe, HAL, Client)
├── docker/
│   ├── yocto/     # kas build container (zion-kas)
│   ├── sdk/       # Yocto cross-toolchain SDK container (zion-sdk)
│   └── esdk/      # Yocto extensible SDK container (zion-esdk)
└── Makefile       # Top-level build orchestration
```

**Boot flow on KV260:**
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
  boot       FAT32   boot.scr + Image + system.dtb + BOOT.BIN + A/B markers
  rootfs-a   ext4    slot A (active after initial flash)
  rootfs-b   ext4    slot B (written by swupdate, then activated)
  home       ext4    /home — persistent, never touched by OTA
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

# 3. Build the Yocto image for KV260 (default board)
make image

# Build artifacts land in:
#   deploy/images/kv260_<timestamp>/  ← .wic.bz2 + .wic.bmap + flash-sdcard.sh
```

Each deploy folder includes an auto-generated, self-contained SD flasher —
use it on any host that has an SD card, no repo needed:

```bash
cd deploy/images/<BOARD>_<TIMESTAMP> && sudo ./flash-sdcard.sh /dev/sdX
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
| `kv260`    | `k26-smk-kv-sdt`  | Zynq UltraScale+ XCZU5EV     |
| `kr260`    | `k26-smk-kr-sdt`  | Zynq UltraScale+ XCZU5EV     |

Add more boards by creating `kas/boards/<name>.yaml` (see [Adding a New Board](#adding-a-new-board)).

---

## Build Targets

```
make image  kv260          Build Yocto SD card image (default board: kv260)
make build  kv260          Alias for image
make rebuild-image kv260   cleansstate image recipe, then rebuild
make sdk    kv260          Cross-toolchain SDK installer → deploy/sdk/
make esdk    kv260          Extensible SDK installer    → deploy/esdk/
make shell  kv260          Interactive kas shell in the build container
make swu                   Build .swu OTA package       → deploy/swu/
make flash  kv260 DEVICE=/dev/sdX   Flash image to SD card

# Validation / CI gates:
make lint                  Makefile + kas YAML sanity
make test                  Host prerequisite check (docker, curl, openssl, ...)
make check-board [BOARD]   Board config validation (no arg: list all boards)
make validate [BOARD]      OTA/signing/security invariants (scripts/validate.sh)

# Override image version for OTA package:
make swu SWU_VERSION=1.2.3

# Docker image management:
make kas-image             Build/rebuild KAS build container
make sdk-image             Full chain: SDK build → Docker image
make esdk-image            Full chain: eSDK build → Docker image

# Artifact deployment (run automatically by build/swu/sdk/esdk):
make deploy-images         Copy .wic + BOOT.BIN + manifest → deploy/images/
make deploy-swu            Copy .swu → deploy/swu/

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

The `.swu` deploy directory also ships an auto-generated `install-ota.sh` helper:

```bash
cd deploy/swu/<BOARD>_<TIMESTAMP>
./install-ota.sh --serve          # host the .swu over HTTP (web UI or curl)
./install-ota.sh --device <ip>    # scp to a running device + install via SSH
./install-ota.sh --copy <dir>     # copy onto a mounted SD/USB stick
```

**Apply OTA on device:**

```bash
# via swupdate web UI (port 8080) or CLI:
swupdate -i /path/to/kv260-<version>.swu
```

**After the update:** the device reboots into the new slot. On every boot
`boot.cmd.zion` (U-Boot) counts unconfirmed boots against the rollback
limit (3). The health check (`swupdate-bootcheck.service`) verifies the
slot is healthy and confirms it by writing `/boot/boot_ok` + clearing the
U-Boot env flag (`bootcount-reset.service` via `fw_setenv`, stored in the
redundant QSPI "U-Boot storage variables" partitions). If the new slot
fails 3 consecutive boots — or the kernel never reaches userspace —
U-Boot clears the slot marker and boots the previous slot automatically.

## QSPI Boot Firmware Update (on device)

The KV260/KR260 SOMs always boot from QSPI, which holds two boot-firmware
slots (Image A / Image B: FSBL + PMU FW + ATF + U-Boot). The image ships
`xmutil`, so new boot firmware (BOOT.BIN) can be flashed from Linux
without JTAG:

```bash
# BOOT.BIN is at /boot/BOOT.bin (baked into the image / updated by OTA)
ssh zion@<device>
sudo xmutil updateboot        # writes BOOT.BIN to the inactive QSPI slot
```

## CI

`.github/workflows/ci.yml` runs on every push/PR:
- `static` — `make lint`, `make test`, `make check-board`, `make validate`
- `build` (matrix kv260/kr260) — full image + signed `.swu` builds on the
  self-hosted `yocto` runner, artifacts uploaded per commit.

---

## Flash to SD Card

```bash
make flash kv260 DEVICE=/dev/sdX
# Uses bmaptool for fast, verified write.
```

Alternatively, every image deploy folder contains a standalone flasher that
works without this repo (bmaptool when available, dd fallback):

```bash
cd deploy/images/kr260_<timestamp>
sudo ./flash-sdcard.sh            # lists candidate devices
sudo ./flash-sdcard.sh /dev/sdX   # confirm, then flash
```

**Identify your SD card device first:**

```bash
lsblk -d -o NAME,SIZE,MODEL
```

---

## KV260 Boot & Flash Instructions

### Initial SD card setup

1. Build the image: `make image kv260`
2. Flash: `make flash kv260 DEVICE=/dev/sdX`
3. Insert the SD card into the KV260 microSD slot.
4. Power on. KV260 always boots from its factory QSPI boot firmware
   (Image A → FSBL → PMU FW → ATF → U-Boot); U-Boot then finds
   `boot.scr` on the SD card and boots Zion-OS from it.
5. Connect a USB-UART cable to the KV260 debug UART (J4) and open a
   serial terminal at **115200 8N1** (`minicom -D /dev/ttyUSB1 -b 115200`).
6. Login: `zion` / `zion` (TTY + SSH; root SSH login is disabled — see
   `meta/meta-zion/recipes-connectivity/openssh/`).

> The Kria QSPI boot firmware chainloads whatever boot media U-Boot finds;
> no boot-mode jumper change is needed for SD boot. To replace the QSPI
> boot firmware itself, use `xmutil updateboot` (section above) or
> `program_flash` from Vitis.

### QSPI boot (production)

BOOT.BIN (FSBL + PMU FW + ATF + U-Boot) can be programmed to QSPI flash for
standalone board boot without an SD card. Use `xsct` or `program_flash` from
Vitis/PetaLinux. Rootfs A/B and the data partition remain on eMMC or SD.

### Recovery (bricked board)

1. Connect JTAG via the KV260 JTAG/USB port and use `xsct`/`program_flash`
   to reprogram the QSPI boot firmware (Image A) with a known-good BOOT.BIN
   (deployed to `deploy/images/<board>_<ts>/BOOT-k26-smk-kv-sdt.bin`).
2. If the QSPI boot firmware still runs but the SD contents are bad:
   re-flash the SD card from any host with the per-deploy
   `flash-sdcard.sh`, or boot U-Boot over JTAG and `tftpboot` a rescue
   kernel + rootfs.
3. Force the previous rootfs slot from Linux (before an OTA goes bad):
   `sudo rm /boot/slot_b /boot/upgrade_pending && sudo reboot` —
   boot.cmd.zion falls back to rootfs-a. From U-Boot, the same marker
   removal via `fatrm` achieves the fallback without Linux.
4. Serial console (UART, 115200 8N1) is always enabled on the boot path
   (kernel `console=ttyPS1` + systemd-getty) as the last-resort interface.

---

## SDK / eSDK

```bash
# Build cross-toolchain SDK (no Docker image):
make sdk kv260
# → deploy/sdk/kv260_<timestamp>/*.sh

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
| `meta-kria`         | Xilinx/meta-kria (rel-v2025.2)            | Kria SOM + KV260 & KR260 machine configs     |
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

- **Platform:** Raspberry Pi → AMD Xilinx Zynq UltraScale+ MPSoC (KV260)
- **BSP layer:** `meta-raspberrypi` → `meta-xilinx` + `meta-xilinx-tools` + `meta-kria`
- **poky source:** upstream → Xilinx fork (`rel-v2025.2`)
- **meta-openembedded source:** upstream → Xilinx fork (`rel-v2025.2`)
- **Custom layer:** `meta-acadia` → `meta-zion`
- **Image recipe:** `acadia-image` → `zion-image`
- **Default board:** `rpi5` → `kv260` (machine: `k26-smk-kv-sdt`)
- **Docker images:** `rpi5-kas`, `rpi5-sdk`, `rpi5-esdk` → `zion-kas`, `zion-sdk`, `zion-esdk`
- **Kernel image:** `kernel_2712.img` (RPi5-specific) → `Image` (standard arm64)
- **DTB:** `bcm2712-rpi-5-b.dtb` → `zynqmp-smk-k26-revA-sck-kr-g-revB.dtb`
- **U-Boot env tool:** `u-boot-fw-utils` → `libubootenv-bin`
- **Removed:** RPi-specific vars (`GPU_MEM`, `ENABLE_UART`, `RPI_USE_U_BOOT`, `rpi_arm64_defconfig`, `synaptics-killswitch` licence)
- **Removed:** All RPi board configs (rpi0–rpi5, cm1–cm5, rpi-armv7, rpi-armv8)
- **Removed:** `patch_health.py` (Acadia-Server specific)
- **Renamed:** `rpi-make-completion.bash` → `zion-make-completion.bash`
- **Updated:** `config` (HAL repository URL: Acadia-HAL → Zion-HAL)
- **Updated:** `req.md` (audit prompt: Acadia-OS → Zion-OS, RPi → KV260)
- **swupdate OTA:** A/B dual-rootfs structure preserved; sw-description path updated to `meta/meta-zion/swupdate/sw-description`
- **Boot flow:** RPi GPU-based boot (config.txt) → Zynq FSBL → PMU FW → ATF → U-Boot → Linux
