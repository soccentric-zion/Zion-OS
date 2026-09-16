# Zion-OS Build and Deployment

## Purpose and scope
Zion-OS builds the Yocto image for the default `kr260` board through kas-container, plus SDK/eSDK installers and swupdate OTA packages. `kas/common.yaml` pins the distro/image and Xilinx/Zion layer set; `kas/boards/kr260.yaml` selects machine `k26-smk-kr-sdt` and the A/B WIC layout.

## 1. Prerequisites
- Linux with Docker, curl, git, Make, and `bmap-tools` for flashing.
- Docker must be usable by the current user. The first build downloads kas-container 4.5 and may fetch Yocto layers and sources.
- Significant disk space for `build`, `downloads`, and `sstate-cache`; use the checked-in cache deliberately.

## 2. Setup
```bash
make kas-image
make image kr260
```
`image` is an alias for `build`; board may also be selected with `BOARD=kr260`. The Makefile's positional board argument must follow the target.

## 3. Build and compile
```bash
make build kr260
make rebuild-image kr260
make shell kr260
make sdk kr260
make esdk kr260
make sdk-image
make esdk-image
```
`build` runs kas/BitBake for `zion-image` and deploys `.wic.bz2` and `.wic.bmap`. `rebuild-image` cleans the recipe state before rebuilding. SDK/eSDK targets run `populate_sdk` or `populate_sdk_ext`; the image variants also stage installers and build Docker images.

## 4. Test and lint

```bash
make lint          # Makefile syntax + kas YAML parse check
make test          # host prerequisites (docker, curl, openssl, python3-yaml)
make check-board   # board config validation; no arg lists all boards
make validate      # static invariants: layer/kas pins, A/B wks ↔ sw-description
                   # ↔ boot.cmd ↔ fw_env chain, signing setup, security
                   # invariants (scripts/validate.sh)
```

`validate` is the pre-build CI gate (also run in CI before image builds);
it catches dead-file and cross-file mismatch bugs (e.g. a kernel fragment
no bbappend applies, or an fw_env config pointing at storage U-Boot never
writes). Boot, service, OTA, rollback, and peripheral checks require a
board and serial/network access.

## 5. Packaging and artifacts
```bash
make swu SWU_VERSION=1.2.3
```
Images are copied to `deploy/images/kr260/` together with
`BOOT-k26-smk-kr-sdt.bin` (QSPI boot firmware for `xmutil updateboot`) and a
`manifest.txt` (board, machine, image, git + meta-zion SHAs, kernel
version); SDK installers to `deploy/sdk/`; eSDK installers to
`deploy/esdk/`; and OTA bundles to `deploy/swu/`. The SWU contains
compressed rootfs, kernel/DTB when found, install hooks, and
`sw-description`. If the private RSA key exists in the ignored key path, it
signs the description; otherwise the Makefile explicitly creates an
unsigned package.

Generate keys only in a protected environment:
```bash
./scripts/generate-swu-keys.sh
```
Keep `swupdate-private.pem` in the CI vault; commit only the public key.

## 6. Deployment, install, and run
```bash
make flash kr260 DEVICE=/dev/sdX
```
This is destructive: identify the SD block device with `lsblk` and independently confirm it before using `bmaptool`. Apply a built `.swu` on the device with swupdate (web UI port 8080 or `swupdate -i ...`) only in a controlled update window. Boot validation uses the KR260 SD/QSPI boot mode, serial UART at 115200 8N1, and the documented A/B health-check confirmation.

## 7. Cleanup
```bash
make clean
make clean-build
make clean-docker
make clean-all
```
`clean`/`clean-build` remove `build`; `clean-docker` removes kas/sdk/esdk images; `clean-all` also removes downloads and sstate-cache and therefore sacrifices reproducibility/cache reuse.

## 8. Hardware, cloud, and manual verification caveats
Image generation for KV260 and KR260 is verified by the build (and by CI); boot, A/B rollback, OTA application, and peripheral behavior still require staged hardware tests on a real board. `flash` and OTA application are destructive and require explicit hardware and manual approval.
