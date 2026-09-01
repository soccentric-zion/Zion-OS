# Changelog

## [Unreleased]

### Fixed — `make build` is now warning-free (was 189 bitbake + 11 kas warnings)

- **161× `Runqueue deadlocked on deferred tasks`** — benign bitbake recovery for
  the SDT multiconfigs (fsbl/r5/pmu): identical native tasks are paired across
  multiconfigs and force-run once sstate covers everything (also affects
  PetaLinux 2025.2; upstream has no fix). Demoted to debug via
  `kas/patches/poky/0001-bitbake-runqueue-Demote-...patch`, applied to poky by
  kas on every checkout (rebase when bumping the poky commit)
- **20× `ZynqMP pmu-rom is not enabled`** — accept the Xilinx license flag
  (`LICENSE_FLAGS_ACCEPTED += " xilinx"`); enables `pmu-rom-native` for QEMU
  ZynqMP emulation, which `kria-qemu-kv.inc` already expects
- **4× meta-xilinx-tools "not enabled via XILINX_WITH_ESW"** — false positive:
  the sanity check only knows the legacy XSCT workflow, our Kria SDT machines
  use `XILINX_WITH_ESW = "sdt"`. Opted out via the documented
  `SKIP_META_XILINX_TOOLS_SANITY_CHECK = "1"`
- **4× meta-virtualization "virtualization not in DISTRO_FEATURES"** — the layer
  is only present because meta-xilinx-standalone-sdt depends on its
  BBFILE collection; containers are unused. Opted out via
  `SKIP_META_VIRT_SANITY_CHECK = "1"`
- **11× kas `Falling back to file-relative addressing`** — all kas include
  paths are now repo-root-relative (`kas/common.yaml`, `kas/repos/*.yaml`)
- New `zion-os` pseudo-repo in `kas/repos/poky.yaml` (host-only, `layers: {}`)
  so the Zion-OS repo can carry patches for upstream layers

### Changed — deploy dir keeps only the newest snapshot per artifact type

- Every deploy target (`deploy-images` / `deploy-sdk` / `deploy-esdk` /
  `deploy-swu`) now automatically **prunes old `BOARD_TS` snapshots** after
  deploying, so `deploy/` holds only **one copy per artifact type and board**
  instead of accumulating ~1.4 GB per build
- New `DEPLOY_KEEP` variable (default `1`) — set e.g. `make image kv260
  DEPLOY_KEEP=3` to retain more history
- New `make prune-deploy PRUNE_TYPE=<images|sdk|esdk|swu>` helper (internal,
  also usable manually)

### Added — self-contained flash/install scripts next to deployed artifacts

- `deploy/images/BOARD_TS/` now also contains an auto-generated
  **`flash-sdcard.sh`** — standalone SD-card flasher for the .wic.bz2 in the
  same folder (bmaptool when a .bmap is present, dd fallback; device type /
  mount / capacity checks; interactive confirm or `-y`)
- `deploy/swu/BOARD_TS/` now also contains an auto-generated
  **`install-ota.sh`** — gets the .swu to the device:
  `--serve` (HTTP → device web UI or curl), `--device <ip>` (ssh + scp +
  `swupdate -i`), or `--copy <dir>` (mounted SD/USB stick)
- Generators: `scripts/generate-flash-sdcard.sh`, `scripts/generate-install-ota.sh`
  (invoked automatically by `deploy-images` / `deploy-swu`)

### Fixed

- `make swu`: stale `meta/meta-zion/swupdate/...` paths replaced with the real
  layer root `meta/meta-zion/meta/meta-zion/swupdate/...` (`ZION_LAYER_DIR`);
  the sw-description/pre-/post-install sources and RSA key path were broken
  after the meta-zion layer moved to its nested repo layout

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
