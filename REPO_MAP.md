# Zion-OS

**Remote:** `git@github.com:soccentric-zion/Zion-OS.git`
**Parent project:** [Zion](../Zion.md) (target hardware: **AMD Xilinx Zynq UltraScale+ MPSoC**, default board **KR260** / Kria KR260 Robotics Starter Kit.)
**Leaf type:** `<Project>-OS`
**Status:** REAL — actively built out

Yocto-based embedded Linux OS for the **Zynq UltraScale+ MPSoC** platform.
Built with `kas` + Docker against the Xilinx `rel-v2025.2` layer set, with A/B
OTA updates via `swupdate`.

**Board:** default `kr260` (positional arg to `make build`). All platform
customization lives in `meta/meta-zion`, a nested clone of its own upstream
`soccentric-zion/meta-zion` (fetched by kas); upstream layers (`poky`,
`meta-openembedded`, `meta-xilinx`, `meta-xilinx-tools`, `meta-kria`,
`meta-swupdate`) are checked out by kas into a **gitignored** `layers/`
directory and must never be hand-edited or tracked.

**Targets:** `make build`, `make image`, `make shell [board]`, `make swu`
(OTA package), `make sdk`/`esdk`, `make flash`, `make deploy-*`,
`make clean`/`clean-all`, plus validation gates `make lint`, `make test`,
`make check-board [board]`, `make validate [board]` (CI in
`.github/workflows/ci.yml`).

**KAS image:** `zion-kas:latest` (built from `docker/yocto/`). `build/`,
`downloads/`, `sstate-cache/` are gitignored bind-mounted host dirs.

**Boot flow (KR260):**
```
SD/QSPI → FSBL → PMU Firmware → ATF (TF-A) → U-Boot → Linux → systemd
        → Zion-HAL, Zion services
```

**A/B OTA layout:** `boot` (FAT32, BOOT.BIN + Image + DTB), `rootfs-a`,
`rootfs-b` (ext4, switched by swupdate), `data` (`/home`, persistent).

**Local layer:** `meta/meta-zion` is a nested clone with its own upstream
at `soccentric-zion/meta-zion.git` (see `.gitignore`).

---
Part of the `Zion` project in the `project-managers` fleet. See
`docs/project-managers.md` for the full 9-project / 8-leaf hierarchy and shared
conventions.
