# Changelog

## [Unreleased]

### Fixed — U-Boot environment actually reachable from Linux (fw_printenv chain)

- **`fw_env.config` pointed at storage U-Boot never writes.** Kria SOMs boot
  QSPI-only, and the Zion U-Boot selects its env driver from the boot-mode
  register (`board/xilinx/zynqmp/zynqmp.c`): QSPI boot → raw env in the
  QSPI partitions *"U-Boot storage variables"* (0x2200000) + redundant
  *"...backup"* (0x2220000). `/boot/uboot.env` (FAT) is only used in SD-mode
  boot, which Kria never does. `fw_env.config` now targets
  `/dev/zion/uboot-env{,-redund}` — stable symlinks created by the new
  `60-zion-uboot-env.rules` from the MTD partition names (survives DT
  partition renumbering). This makes the OTA confirm path
  (`bootcount-reset.service` → `fw_setenv upgrade_available 0`) functional
  on both KV260 and KR260
- **`swupdate-start.sh` crashed on the placeholder signing key** — the
  committed public-key file was a non-parseable placeholder, and the
  wrapper passed `-k` whenever the file existed. It now validates the PEM
  with `openssl pkey -pubin` before enabling verification (and a real
  RSA-4096 keypair has been generated: public key committed, private key
  gitignored in `swupdate/keys/`)

### Added — kernel enablement for full MPSoC feature set

- **`recipes-kernel/linux/linux-xlnx_%.bbappend`** now actually applies the
  `zion-base.cfg` fragment (previously a dead file — no bbappend
  referenced it). Verified against the rel-v2025.2 kernel tree, enables:
  `CONFIG_SPI_SPIDEV` (user-space SPI), `CONFIG_XILINX_AMS` +
  `CONFIG_SENSORS_IIO_HWMON` (system-monitor temperature/voltage via
  lm-sensors), `CONFIG_CRYPTO_DEV_XILINX_TRNG` (PMU-firmware true RNG →
  kernel entropy), `CONFIG_BLK_DEV_NVME` (PCIe NVMe),
  `CONFIG_CAN_MCP251X(_FD)` (SPI CAN/FD controllers)

### Added — security hardening

- **openssh bbappend** ships `/etc/ssh/sshd_config.d/50-zion.conf`:
  `PermitRootLogin no` (root is password-locked in the image),
  `MaxAuthTries 4`; documented operator login is `zion`/`zion`
- **`zion` user joins `systemd-journal`** — log-forwarding clients can read
  the full persistent journal without root

### Added — Kria SOM monitoring

- `lmsensors-sensors` + meta-kria `lmsensors-config-kria-fancontrol` in the
  image: `sensors` reports SOM temperature/voltage rails; Kria fan control
  config ships

### Added — validation gates and CI

- New make targets: **`make lint`** (Makefile/kas YAML parse), **`make
  test`** (host prerequisites incl. docker daemon), **`make check-board`
  [BOARD]** (board config validation / board listing), **`make validate`
  [BOARD]** (`scripts/validate.sh` — layer/kas pin coherence, A/B wks ↔
  sw-description ↔ boot.cmd ↔ fw_env chain, signing setup, security
  invariants). All documented in README and in bash completion
- **GitHub Actions CI** (`.github/workflows/ci.yml`): static gates on every
  push/PR; full image + signed `.swu` build matrix (kv260, kr260) on the
  self-hosted `yocto` runner with artifact export
- **`deploy-images` now ships BOOT.BIN** alongside the .wic artifacts and
  writes a `manifest.txt` (board, machine, image, git + meta-zion SHAs,
  kernel version) for traceability
- Reproducible-build settings in `kas/common.yaml`
  (`SOURCE_DATE_EPOCH`, `BUILD_REPRODUCIBLE_BINARIES`)

### Fixed — documentation accuracy

- README rewritten: KV260 boots from factory QSPI boot firmware (no boot
  mode jumper), correct OTA service names (`swupdate-bootcheck.service`,
  `bootcount-reset.service`, `boot-watchdog.service`), A/B layout docs now
  match the wks (persistent `/home` partition), new QSPI boot-firmware
  update section (`xmutil updateboot`), realistic recovery runbook
- meta-zion layer README: fw_env storage model + udev symlinks documented

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
