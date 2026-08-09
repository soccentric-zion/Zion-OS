# Changelog

## [Unreleased]

### Added — full feature-complete OS layer (`meta/meta-zion`)

- **Complete Yocto layer** committed locally in `meta/meta-zion`:
  - `recipes-core/images/zion-image.bb` + `zion-image-common.inc` + 20
    per-domain image variants (aerospace, automotive, medical, defense, etc.)
  - `recipes-core/zion-data-init` — first-boot persistent `/home` init
  - `recipes-core/zion-services` — dmesg capture + disk-usage monitoring
  - `recipes-core/systemd` — persistent journal + NTP timesyncd config
  - `recipes-core/os-release` — identifies image as "Zion OS"
  - `recipes-core/packagegroup-zion-middleware` / `-cloud` — gRPC/protobuf
    and cloud/telemetry package groups
  - `recipes-connectivity/zion-connectivity` — Ethernet/WiFi/Bluetooth
  - `recipes-connectivity/zion-timesync` — enable systemd-timesyncd
  - `recipes-bsp/zion-hal` — HAL recipe (CMake + gRPC)
  - `recipes-support/expand-rootfs` — grow root to fill SD card
  - `recipes-support/swupdate` — RSA signing config fragment
  - `recipes-swupdate/zion-swupdate-config` — A/B OTA runtime (bootcheck,
    boot-watchdog, bootcount-reset, web UI auth, swupdate.cfg)
  - `wic/sdimage-zynqmp.wks` — A/B OTA partition layout
  - `swupdate/sw-description` + `pre-install.sh` + `post-install.sh`
- **`scripts/generate-swu-keys.sh`** — RSA-4096 keypair generator
- **`CLAUDE.md`** and **`REPO_MAP.md`** — project documentation

### Fixed

- `.gitignore` now tracks `meta/meta-zion/` locally (matching Acadia/Arches
  convention) while continuing to ignore upstream `layers/`.

### Notes

- Zion-OS is a direct port of the Acadia-OS reference template, retargeted
  from Raspberry Pi 5 → Zynq UltraScale+ MPSoC (KR260). Boot chain, A/B OTA,
  and service layout preserved; device paths, kernel image (`Image`), DTB
  (`zynqmp-smk-k26-revA-sck-kr-g-revB.dtb`), and U-Boot env flow adapted.
