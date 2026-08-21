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
There is no standalone unit-test target in the Makefile. The build is the primary BitBake validation; use `make shell kr260` for targeted BitBake inspection. Boot, service, OTA, rollback, and peripheral checks require a board and serial/network access.

## 5. Packaging and artifacts
```bash
make swu SWU_VERSION=1.2.3
```
Images are copied to `deploy/images/kr260_<timestamp>/`; SDK installers to `deploy/sdk/`; eSDK installers to `deploy/esdk/`; and OTA bundles to `deploy/swu/`. The SWU contains compressed rootfs, kernel/DTB when found, install hooks, and `sw-description`. If the private RSA key exists in the ignored key path, it signs the description; otherwise the Makefile explicitly creates an unsigned package.

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
The default machine is KR260, not proof of support for another Zion board. Image generation does not prove boot, QSPI, A/B rollback, signing, recovery, systemd services, or device peripherals. `flash`, OTA application, signing, and cloud/CI artifact publication require explicit hardware, credentials/keys, and manual approval.
