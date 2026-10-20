# Linux

Mainline Linux **v7.2.11** with a minimal config, and a small BusyBox root filesystem. Boots in about 3 seconds;
about 40 MiB of the 115 MiB `MemTotal` is in use with everything running.

## Boot

U-Boot boots slot A or B ([ota.md](ota.md#boot)): `kernel.itb` (kernel and device tree, `board/ulanzi/d200/kernel.its`)
from the UBI volume `kernel_a` or `kernel_b`, and the read-only UBIFS root from `rootfs_a` or `rootfs_b`. The
command line, for slot A:
```
console=ttyS2,1500000n8 earlycon ubi.mtd=ubi rootfstype=ubifs ro panic=10 root=ubi0:rootfs_a d200.slot=a
```

## Kernel

- Patches: `board/ulanzi/d200/patches/linux/7.2.11/`. The D200 device tree files are the same as U-Boot's.
- Config: `board/ulanzi/d200/linux.config`, started from `allnoconfig`. Everything is built in, no modules:
  - SoC: clocks, pinctrl, GPIO, UART, watchdog;
  - storage: SPI NAND, UBI, UBIFS (LZO only);
  - USB device mode (DWC2) with configfs gadgets: HID, NCM, mass storage;
  - IPv4 and IPv6;
  - display: DRM/KMS (VOP, RGB output, panel, PWM backlight); no fbdev, no fbcon;
  - keys: matrix keypad on evdev;
  - CPU: cpufreq-dt (408/600/816 MHz, `schedutil`), thermal throttling.
- To change the config (after one `make build`):
  ```bash
  make shell
  . scripts/buildroot-env.sh release      # or debug
  br_make linux-menuconfig
  br_make linux-update-defconfig          # writes board/ulanzi/d200/linux.config
  exit
  make linux-rebuild
  ```

## Root filesystem

BusyBox init. Debug builds add a root shell on the UART (`ttyS2`, no login) and SSH over USB Ethernet; release
builds have neither. Services:

| Service | What |
|---|---|
| `S00data` | Mounts the UBI volume `data` at `/data` (formats it if it doesn't mount, erases it on a device reset), empties `/data/update`, restores the clock |
| `S10loopback` | Brings up `lo` |
| `S15watchdog` | Feeds `/dev/watchdog` (60 s timeout, started by U-Boot) |
| `S30usb-gadget` | USB functions, USB Ethernet addresses, DHCP server and IPv6 router advertisements, the hostname `d200-<serial>`. `apply` applies the USB settings ([USB](#usb)) |
| `S50dropbear` | Debug builds only. SSH and SFTP on USB Ethernet; root without a password |
| `S50mdnsd` | mDNS: `d200-<serial>.local` and the web server (`_http._tcp`), plus SSH in debug builds |
| `S60deckd` | [`deckd`](https://github.com/riptidewave93/d200-deck): the key app and the update page on port 80. Restarted if it exits or hangs |
| syslogd, klogd | Logs in RAM: `/var/log/messages` |

Files added to Buildroot's default skeleton live in `board/ulanzi/d200/rootfs-overlay/`.

The root filesystem is read-only. What's kept across boots lives in `/data` (100 MiB): the key app's config, the
USB settings, the saved clock, the random seed, the SSH host key (debug builds) and an incoming update. Logs,
leases and PID files stay in RAM. A device reset (`/data/.reset`, written by `deckd`) erases all of `/data` at the
next boot, and everything comes back with its defaults. The U-Boot env is read and written with `fw_printenv` /
`fw_setenv`.

**Clock:** there is no RTC. The clock starts from the time saved in `/data/clock` or the build time, whichever is
later. `deckd` sets it from the PC when the PC app connects, and saves it.

`reboot-to [normal|fastboot|maskrom]` reboots into U-Boot's fastboot, the BootROM's USB download mode, or normally.

## USB

The USB-C port is one composite device, `1d6b:0104` "Ulanzi D200", whose USB serial number is the CPU serial.
Functions are set in `/etc/default/usb-gadget`:

| Function | PC sees | D200 side |
|---|---|---|
| `hid` | Keyboard, media keys, system control, mouse | `/dev/hidg0`; `deckd` provides the report descriptor |
| `raw` | A vendor HID device (usage page `0xFFD2`): the config channel for the website (WebHID) and the PC app | `/dev/hidg1`, served by `deckd` |
| `ncm` | USB Ethernet (built-in driver on Linux, macOS, Windows 10/11) | `usb0`, addresses below |
| `msc` | Read-only USB drive "D200 DECK" with a README showing the D200's name and addresses | Built from `board/ulanzi/d200/usb-drive/` |

**Settings** are `KEY=value` lines in `/data/usb-gadget.conf`, written by `deckd`. A missing or invalid value means
the default:

| Key | Default | Set |
|---|---|---|
| `drive` | `1`: the USB drive is on | `0`: no USB drive |
| `net4` | The `/30` derived from the serial (below) | An IPv4 address: the D200 uses the `/30` holding it (the D200 first, the PC second) |

`/etc/init.d/S30usb-gadget apply` applies a change; the PC then sees the D200 unplugged and plugged back in.

**USB Ethernet:** the D200 is `d200-<serial>.local` over mDNS (`<serial>` is the USB serial number, lowercase);
debug builds: `ssh root@d200-<serial>.local`. Each D200 has its own addresses, derived from its serial, so several
D200s on one PC don't clash:

- IPv4: a `/30` in `198.18.0.0/15`. The D200 is the first address; its DHCP server gives the PC the second, with
  no gateway and no DNS, so the PC keeps its normal network.
- IPv6: a ULA `/64`. The D200 is `::1`; the PC picks its own address, with no default route through the D200.
- Without a CPU serial: `172.31.254.1/30`, IPv4 only.

Proxy tools in "fake-IP" mode (Clash, sing-box, Surge) also use `198.18.0.0/15`; if one clashes, move the D200
with `net4`.

## Display and keys

| Item | Value |
|---|---|
| Display | `/dev/dri/card0` (driver `rockchip`), one DPI connector, one mode: 720x1280 at ~36 Hz |
| Orientation | The panel is portrait in a landscape device (`panel orientation`: Right Side Up). The kernel doesn't rotate; userspace draws rotated |
| Backlight | `/sys/class/backlight/backlight`, levels 0-255, 255 at boot |
| Keys | `/dev/input/event0` ("keypad"), one press/release per key, no autorepeat |

Key codes, in reading order (as seen from the front):

| Keys | Codes |
|---|---|
| 0-4 (top row) | `KEY_F13`..`KEY_F17` |
| 5-9 (middle row) | `KEY_F18`..`KEY_F22` |
| 10-11 (bottom row) | `KEY_F23`, `KEY_F24` |
| 12 (bottom row) | `KEY_PROG1` |
| 13 (wide bottom-right key) | `KEY_PROG2` |

Quick checks (debug builds): `modetest -M rockchip -c` (connectors and properties), `hexdump -C /dev/input/event0`
(press keys).
