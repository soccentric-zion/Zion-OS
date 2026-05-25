# SWUpdate OTA for KR260

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [SD Card Partition Layout](#sd-card-partition-layout)
3. [Update Flow — Step by Step](#update-flow--step-by-step)
4. [File Map](#file-map)
5. [Building an Update Package](#building-an-update-package)
6. [Delivering an Update](#delivering-an-update)
7. [Web UI Manual](#web-ui-manual)
8. [CLI Manual](#cli-manual)
9. [On-Device Manual](#on-device-manual)
10. [Rollback](#rollback)
11. [Customising the Update Package](#customising-the-update-package)
12. [Troubleshooting](#troubleshooting)

---

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│              KR260 Robotics Starter Kit — microSD card               │
│                                                                      │
│  ┌──────────┐  ┌────────────────┐  ┌────────────────┐  ┌──────────┐ │
│  │  p1/boot │  │  p2/rootfs-a   │  │  p3/rootfs-b   │  │  p4/home │ │
│  │  256 MB  │  │    8192 MB     │  │    8192 MB     │  │  ~rest   │ │
│  │  FAT32   │  │    ext4        │  │    ext4        │  │   ext4   │ │
│  │ BOOT.BIN │  │  ← active →    │  │  ← standby →   │  │  /home   │ │
│  │ Image    │  │                │  │  written by    │  │  (data)  │ │
│  │ DTB      │  │                │  │  SWUpdate      │  │          │ │
│  └──────────┘  └────────────────┘  └────────────────┘  └──────────┘ │
│       │                ▲                    ▲                        │
│  U-Boot reads     bootslot=a/b         fw_setenv                     │
│  U-Boot env       (current boot)       post-install.sh               │
└──────────────────────────────────────────────────────────────────────┘
```

**A/B rootfs model** — the device always has two complete root filesystems:
- **Slot A** (`/dev/mmcblk1p2`, label `rootfs-a`) — factory-flashed active slot.
- **Slot B** (`/dev/mmcblk1p3`, label `rootfs-b`) — standby; SWUpdate writes the
  new image here while the system keeps running normally.

The `/boot` partition (FAT32) is shared and contains `BOOT.BIN` (FSBL + PMU FW +
TF-A + U-Boot), `Image`, and the board DTB.  A/B slot selection is controlled by
U-Boot environment variables, **not** by editing a text file:

| Variable | Values | Meaning |
|----------|--------|---------|
| `bootslot` | `a` / `b` | Which rootfs partition to boot |
| `upgrade_available` | `0` / `1` | 1 = trial boot of new slot pending confirmation |
| `bootcount` | integer | Incremented by U-Boot; reset to 0 after confirmation |

`post-install.sh` calls `fw_setenv` to set `bootslot=<new>` and
`upgrade_available=1`. After a successful boot `swupdate-bootcheck.service` sets
`upgrade_available=0` to confirm the slot and prevent U-Boot rollback.

The `/home` partition (p4) is **never touched** by an OTA update.  It expands to
fill the remaining card space on first boot (via `kr260-home-init.service`).

---

## SD Card Partition Layout

| # | Label | Size | FS | Mount | Purpose |
|---|-------|------|----|-------|---------|
| p1 | `boot` | 256 MB | FAT32 | `/boot` | BOOT.BIN, Image, DTB |
| p2 | `rootfs-a` | 8192 MB | ext4 | `/` | Root filesystem — Slot A (active after factory flash) |
| p3 | `rootfs-b` | 8192 MB | ext4 | *(none)* | Root filesystem — Slot B (standby, target of next OTA) |
| p4 | `home` | ~rest of card | ext4 | `/home` | Persistent user / application data |

---

## Update Flow — Step by Step

```
Developer workstation                       KR260
─────────────────────────────────────────────────────────────────────
make swu SWU_VERSION=1.2.3
  → gzip rootfs.ext4 to rootfs.ext4.gz
  → substitute @@VERSION@@ in sw-description
  → cpio-pack → zion-1.2.3.swu

Upload zion-1.2.3.swu  ───────────────────►  SWUpdate daemon receives .swu
(web UI :8080 or swupdate-client)
                                             1. Verify sw-description signature
                                                (if signing enabled)
                                             2. Run pre-install.sh
                                                • findmnt / → active device
                                                • blkid -L rootfs-a/rootfs-b
                                                  to find inactive slot
                                                • ln -sf <inactive> /dev/swupdate-inactive
                                                • echo <slot> > /run/swupdate-target-slot
                                             3. Stream rootfs.ext4.gz → raw write
                                                to /dev/swupdate-inactive
                                             4. Run post-install.sh
                                                • read /run/swupdate-target-slot
                                                • fw_setenv bootslot <slot>
                                                • fw_setenv upgrade_available 1
                                                • fw_setenv bootcount 0
                                             5. postupdatecmd = /sbin/reboot
                                                (configured in swupdate.cfg)

                                             ── reboot ──

                                             U-Boot reads env: bootslot=b
                                             → mounts rootfs-b as root
                                             → boots new slot

                                             swupdate-bootcheck.service runs:
                                             • detects active slot via labels
                                             • fw_setenv upgrade_available 0
                                             • fw_setenv bootcount 0
                                             → upgrade confirmed
```

---

## File Map

```
meta/meta-zion/
├── swupdate/                              ← .swu packaging sources (host-side)
│   ├── sw-description                     Template; @@VERSION@@ substituted by make swu
│   ├── pre-install.sh                     Copied verbatim into every .swu
│   └── post-install.sh                    Copied verbatim into every .swu
│
└── recipes-swupdate/
    └── kr260-swupdate-config/
        ├── kr260-swupdate-config.bb       BitBake recipe
        └── files/
            ├── swupdate.cfg               libconfig runtime config (installed to /etc/)
            ├── fw_env.config              libubootenv device map (installed to /etc/)
            ├── pre-install.sh             Installed to /usr/lib/kr260-swupdate/
            ├── post-install.sh            Installed to /usr/lib/kr260-swupdate/
            ├── swupdate-bootcheck.sh      Boot-slot health check (runs at sysinit)
            ├── swupdate-bootcheck.service systemd unit for bootcheck
            └── swupdate-webui.conf        nginx reverse-proxy for swupdate web UI
```

---

## Building an Update Package

### Prerequisites (host)

- A successful `make build` that produced `zion-image-kr260*.rootfs.ext4`
- `gzip` and `cpio` available on the host (standard on any Linux workstation)

### Commands

```bash
# Use the current timestamp as version (default)
make swu

# Explicit version string
make swu SWU_VERSION=1.2.3

# Override build dir
make swu BUILD_DIR=/opt/zion-build SWU_VERSION=2.0.0
```

The output is written to `build/zion-<version>.swu`.

### What `make swu` does internally

1. Finds the latest `*.rootfs.ext4` in `build/tmp/deploy/images/kr260-robotics/`.
2. gzip-compresses it to `build/swu/rootfs.ext4.gz`.
3. Substitutes `@@VERSION@@` in `meta/meta-zion/swupdate/sw-description` → `build/swu/sw-description`.
4. Copies `pre-install.sh` and `post-install.sh` into `build/swu/`.
5. Packs the four files in the required cpio order:
   ```
   sw-description   ← must be first — SWUpdate reads it before anything else
   pre-install.sh
   post-install.sh
   rootfs.ext4.gz
   ```
6. Writes `build/zion-<version>.swu`.

---

## Delivering an Update

### Web UI

1. Find the device IP: `ping kr260.local` or check your router DHCP leases.
2. Open `http://<device-ip>:8080` in a browser.
3. The SWUpdate React front-end (`swupdate-www`) loads.
4. Drag-and-drop `build/zion-<version>.swu` onto the upload area, or click
   **Select file** and choose it.
5. Click **Start update**.
6. Progress is shown in real time via a WebSocket. When it reaches 100% the
   device reboots automatically (controlled by `postupdatecmd` in `swupdate.cfg`).

### CLI — `swupdate-client` (from the host)

```bash
# Basic push
swupdate-client <device-ip> build/zion-1.2.3.swu

# Verbose progress
swupdate-client -v <device-ip> build/zion-1.2.3.swu

# Custom port
swupdate-client -p 8080 -v <device-ip> build/zion-1.2.3.swu
```

Exit code `0` = success, non-zero = failure (check stderr / device logs).

### curl — direct HTTP multipart POST

```bash
curl -X POST http://<device-ip>:8080/upload \
     -F "file=@build/zion-1.2.3.swu"
```

---

## Web UI Manual

| URL | Description |
|-----|-------------|
| `http://<ip>:8080` | Upload page — drag-and-drop or file picker |
| `http://<ip>:8080/api/v1/versioning` | JSON: software + hardware version |
| `http://<ip>:8080/api/v1/sw-components` | JSON: installed SW components |

**Update steps via web UI:**

1. Navigate to `http://<ip>:8080`.
2. The page shows the current installed version (from `swupdate.cfg`).
3. Drop the `.swu` file or use the **Select file** button.
4. Click **Start update**. A progress bar and live log appear.
5. On completion the daemon logs "SUCCESS" and triggers `postupdatecmd`
   (default: `/sbin/reboot`).
6. After reboot, reload the page and verify the version number changed.

**To disable auto-reboot** (for testing):
```bash
# On the device:
sed -i 's|postupdatecmd.*|# postupdatecmd disabled;|' /etc/swupdate.cfg
systemctl restart swupdate
```

---

## CLI Manual

### On the device

```bash
# Check running SWUpdate version
swupdate --version

# Read the live progress socket
swupdate-progress

# Apply a local .swu file (e.g. copied via scp)
swupdate -v -i /tmp/zion-1.2.3.swu

# Dry-run (parses + validates sw-description but does not flash)
swupdate -v --dry-run -i /tmp/zion-1.2.3.swu

# Query active slot (written by swupdate-bootcheck.service at boot)
cat /run/swupdate-active-slot
```

### On the host

```bash
# Send and monitor interactively
swupdate-client -v <ip> build/zion-1.2.3.swu

# Non-interactive (scriptable) — exit code reflects success/failure
swupdate-client <ip> build/zion-1.2.3.swu && echo OK || echo FAILED

# Check installed version via REST API
curl -s http://<ip>:8080/api/v1/versioning | python3 -m json.tool
```

---

## On-Device Manual

### systemd services

```bash
# Status of the SWUpdate daemon
systemctl status swupdate

# View logs
journalctl -u swupdate -f

# Restart daemon (e.g. after editing swupdate.cfg)
systemctl restart swupdate

# Status of the boot-check service
systemctl status swupdate-bootcheck
journalctl -u swupdate-bootcheck
```

### Inspect partition layout

```bash
# Show partition table
lsblk -o NAME,SIZE,FSTYPE,LABEL,MOUNTPOINT /dev/mmcblk1

# Show active root device
findmnt -n -o SOURCE /

# Show current U-Boot env slot selection
fw_printenv bootslot upgrade_available bootcount
```

### Manually switch slot (emergency)

If you need to boot the other slot without an OTA:

```bash
# Check current slot
fw_printenv bootslot

# Switch to slot b (if currently on a, or vice versa)
fw_setenv bootslot b
fw_setenv upgrade_available 0
reboot
```

---

## Rollback

Automatic rollback is supported via U-Boot's `bootcount` / `upgrade_available`
mechanism:

- After `post-install.sh` sets `upgrade_available=1`, U-Boot increments
  `bootcount` on each boot attempt.
- If the system never confirms the upgrade (e.g. it crashes before
  `swupdate-bootcheck.service` runs), U-Boot can be configured to fall back to
  the previous slot when `bootcount` exceeds a threshold.

Configure this in the U-Boot boot script (meta-zion U-Boot env / meta-kria
board support) with something like:

```
if test ${upgrade_available} = 1; then
    if test ${bootcount} > 3; then
        setenv bootslot ${previous_bootslot}
        setenv upgrade_available 0
        setenv bootcount 0
        saveenv
    fi
fi
```

Manual rollback (immediate):

```bash
# Determine the previous slot
fw_printenv bootslot   # shows current slot, switch to the other

fw_setenv bootslot a   # (or b, whichever is the known-good slot)
fw_setenv upgrade_available 0
reboot
```

---

## Customising the Update Package

### Partial update (config files only, no rootfs flash)

Edit `meta/meta-zion/swupdate/sw-description` — remove the `images:` block,
keep only the `scripts:` block, and add a `files:` section:

```
files: (
    {
        filename    = "my-app.conf";
        path        = "/etc/my-app/my-app.conf";
        type        = "rawfile";
        sha256      = "<sha256sum of the file>";
    }
);
```

### Signing packages (recommended for production)

SWUpdate supports RSA / CMS signatures. High-level steps:

```bash
# Generate key pair (one-time, keep private key offline)
openssl genrsa -out swupdate-priv.pem 4096
openssl req -new -x509 -key swupdate-priv.pem -out swupdate-cert.pem

# Sign the sw-description
openssl smime -sign -in sw-description -out sw-description.sig \
    -signer swupdate-cert.pem -inkey swupdate-priv.pem \
    -nodetach -outform DER

# Add to cpio (sw-description.sig must immediately follow sw-description)
printf 'sw-description\nsw-description.sig\n...' | cpio -ov -H newc > signed.swu
```

On the device, add to `/etc/swupdate.cfg`:
```
security: { sigtype = "cms"; certfile = "/etc/swupdate-cert.pem"; };
```

Rebuild and deploy the device image with the cert baked in.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Web UI unreachable | `swupdate` not running | `systemctl start swupdate; journalctl -u swupdate` |
| Upload succeeds but nothing happens | `postupdatecmd` disabled | Check `/etc/swupdate.cfg` |
| Device boots old slot after update | `fw_setenv` failed or `fw_env.config` wrong | Check `journalctl -u swupdate`; verify `/etc/fw_env.config` device/offset |
| `fw_printenv: can't open` | `libubootenv-bin` not installed or wrong config | Check `IMAGE_INSTALL` includes `libubootenv-bin`; check `/etc/fw_env.config` |
| `pre-install.sh: Cannot find rootfs-a/rootfs-b` | SD card not flashed with `sdimage-zynqmp.wks` | Re-flash using the correct WKS image |
| `do_package` error about `swupdate.service` | Recipe listed foreign unit in `SYSTEMD_SERVICE` | Only list units installed by the recipe itself |
| `cpio: File ... truncated` | `.swu` built with wrong order | `sw-description` must be the **first** file in the archive |
| `swupdate-client: connection refused` | Wrong port or firewall | Default port is `8080`; check `swupdate-webui.conf` |
