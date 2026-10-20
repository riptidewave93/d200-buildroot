# Linux

Mainline Linux **v7.2.11** with a minimal config, and a small BusyBox root filesystem. Boots in
about 3 seconds and uses ~28 MiB of its ~115 MiB `MemTotal` with the key app running.

## Boot

U-Boot boots one of two slots, A or B ([ota.md](ota.md#boot)): it reads `kernel.itb` from the UBI volume
`kernel_a` or `kernel_b` and boots it. The FIT image holds the gzipped kernel and the D200 device tree
(`board/ulanzi/d200/kernel.its`). The root filesystem is UBIFS in `rootfs_a` or `rootfs_b`, mounted read-only.

U-Boot sets the kernel command line, for slot A:
```
console=ttyS2,1500000n8 earlycon ubi.mtd=ubi rootfstype=ubifs ro panic=10 root=ubi0:rootfs_a d200.slot=a
```
The kernel has slot A's line built in, for when U-Boot passes none.

## Kernel

- Patches: `board/ulanzi/d200/patches/linux/7.2.11/`: RK3308 VOP support, a generic `rockchip,cmd-panel` panel
  driver, RK3308B-S TSADC support, the RK3308 VOP node, the RK3308B-S SoC dtsi (OPPs, TSADC) and the D200 device
  tree (the same DT files U-Boot uses, [u-boot.md](u-boot.md#patches)), a DWC2 fix so the gadget survives the
  PC sleeping, DWC2 remote wakeup so a key press can wake the PC, and valid HID endpoint descriptors at full speed for
  reports over 64 bytes.
- Config: `board/ulanzi/d200/linux.config`, started from `allnoconfig`. Everything is built in, no modules:
  - SoC: clocks, pinctrl, GPIO, UART, watchdog;
  - storage: SPI NAND, UBI, UBIFS (LZO only; the rootfs is built with LZO);
  - USB device mode (DWC2 + PHY) with configfs gadgets: HID, NCM, mass storage;
  - IPv4 (with multicast, for mDNS) and IPv6;
  - display: DRM/KMS (VOP, RGB output, panel, PWM backlight), 12 MiB CMA; no fbdev, no fbcon;
  - keys: matrix keypad on evdev;
  - CPU: cpufreq-dt (408/600/816 MHz, `schedutil`) on the PWM `vdd_core` regulator, TSADC thermal zone with CPU
    throttling.
- To change the config:
  ```bash
  make shell
  cd BuildEnv/buildroot
  BR2_EXTERNAL=/repo make linux-menuconfig
  BR2_EXTERNAL=/repo make linux-update-defconfig    # writes board/ulanzi/d200/linux.config
  exit
  make linux-rebuild
  ```

## Root filesystem

BusyBox init. Debug builds add a root shell on the UART (`ttyS2`, no login) and SSH over USB Ethernet; release
builds have neither. Services:

| Service | What |
|---|---|
| `S00data` | Mounts the UBI volume `data` at `/data` (formats it if it doesn't mount), and empties `/data/update` |
| `S10loopback` | Brings up `lo` (`127.0.0.1`, `::1`); there are no ifupdown network scripts |
| `S15watchdog` | Feeds `/dev/watchdog`. U-Boot starts it with a 60 s timeout, so a hung system resets |
| `S30usb-gadget` | USB functions; USB Ethernet addresses, DHCP server (udhcpd) and IPv6 router advertisements (radvd); the hostname `d200-<serial>`. `apply` applies the USB settings ([USB](#usb)) |
| `S50dropbear` | Debug builds only. SSH server on USB Ethernet (the only network); root without a password. Includes SFTP, so `scp`/`sftp` work |
| `S50mdnsd` | mDNS on USB Ethernet: answers for `d200-<serial>.local` and advertises the web server (`_http._tcp`), plus SSH in debug builds |
| `S60deckd` | `deckd` ([d200-deck](https://github.com/riptidewave93/d200-deck), packaged in `package/d200-deck`): the key app and the update page on port 80 ([update.md](update.md)), each restarted when it exits. `deckd` itself is restarted when it exits or hangs: when its heartbeat, `/run/deckd.alive`, doesn't change for 60 s. Its config and update state are in `/data/deckd` |
| syslogd, klogd | BusyBox defaults. Logs go to `/var/log/messages`, in RAM (`/var/log` is `/tmp`), about 400 KB at most |

Files added to Buildroot's default skeleton live in `board/ulanzi/d200/rootfs-overlay/`.

The root filesystem is read-only. Everything kept across boots lives in `/data` (UBIFS, 100 MiB): the key app's
config, the USB settings (`/data/usb-gadget.conf`), the saved clock (`/data/clock`), the random seed
(`/data/seedrng`), the SSH host key (debug builds, `/etc/dropbear` links to `/data/dropbear`), and an incoming update
(`/data/update`). The U-Boot env (slot and update state) is read and written with `fw_printenv` / `fw_setenv`.

**Clock:** there is no RTC. At boot, `S00data` sets the clock to the saved time or the build time (`BUILD_ID`),
whichever is later, so it never starts in 1970. `deckd` sets it from the PC when the PC app connects, and saves it
to `/data/clock` (Unix seconds) then and every 6 hours; a clean shutdown saves it too. After a power cut the clock
is behind until the PC app connects.

**Flash writes** are kept rare to spare the SPI NAND. Logs, leases and PID files live in RAM (`/tmp`, `/run`), and
UBIFS doesn't update access times (`UBIFS_ATIME_SUPPORT` is off), so reading files writes nothing. What does write:
the random seed (at boot and shutdown), UBI's fastmap (once per boot), the SSH host key (debug builds, once),
the clock (a few times a day), config changes, and updates. UBI spreads erases over all blocks and handles bad
blocks.

`reboot-to [normal|fastboot|maskrom]` (`package/d200-utils`) reboots into a boot mode: `fastboot` makes U-Boot start
fastboot, `maskrom` makes the BootROM enter USB download mode, `normal` (the default) just reboots.

## USB

The USB-C port is one composite device, `1d6b:0104` "Ulanzi D200", whose USB serial number is the CPU serial.
Functions are set in `/etc/default/usb-gadget`:

| Function | PC sees | D200 side |
|---|---|---|
| `hid` | Keyboard, media keys, system control, mouse | `/dev/hidg0`. `deckd` provides the report descriptor and sends the reports; without it the function is skipped |
| `raw` | A vendor HID device (usage page `0xFFD2`): the config channel for the website (WebHID) and the PC app. Input reports are as long as `deckd raw-report-length` says (1024 bytes, every 125 µs), output reports go over the control endpoint | `/dev/hidg1`, served by `deckd` |
| `ncm` | USB Ethernet (built-in driver on Linux, macOS, Windows 10/11) | `usb0`, addresses below |
| `msc` | Read-only USB drive "D200 DECK" with a README, including the D200's name and addresses | `/tmp/usb-drive.img`: a RAM copy of `/usr/share/d200/usb-drive.img` (built from `board/ulanzi/d200/usb-drive/`) with the README filled in at boot and when the addresses change |

The order is the interface order, and it is fixed: always-on functions first, the drive last, so turning the drive off
renumbers nothing. `bcdDevice` is the USB layout version: it changes when the always-on interfaces or the OS
descriptors change, not with the drive setting. Microsoft OS descriptors (vendor code `0xcd`) give NCM the `WINNCM`
compatible ID, so Windows binds its NCM driver without an INF; keep them. The functions use 5 of the controller's 6
IN endpoints ([hardware.md](hardware.md#usb)). Each IN endpoint gets the smallest free TX FIFO its packets fit: the
config channel's 1024-byte packets need the one 1 KiB FIFO, NCM and the drive the two 512-byte ones, so no other
function may have IN packets over 64 bytes. At full speed, packets are at most 64 bytes and a longer report takes
several.

**Settings** are `KEY=value` lines in `/data/usb-gadget.conf`. A missing or invalid value means the default:

| Key | Default | Set |
|---|---|---|
| `drive` | `1`: the USB drive is on | `0`: no USB drive |
| `net4` | The `/30` derived from the serial (below) | An IPv4 address: the D200 uses the `/30` holding it (the D200 first, the PC second). A dotted quad without leading zeros, first number 1-223 and not 127 |

`deckd` writes the file, keeping lines it doesn't know, and runs `/etc/init.d/S30usb-gadget apply`. That changes the
running gadget only if a setting changed. Then the PC sees the D200 unplugged and plugged back in (and asks for an
address again), and `/dev/hidg0` and `/dev/hidg1` are recreated, so they must be reopened.

**Remote wakeup:** the configuration has the remote wakeup bit (`bmAttributes` `0xa0`). While the PC has the bus
suspended (asleep, or the device selectively suspended), writes to `/dev/hidg0` fail with `EAGAIN`; writing `1` to
`/sys/class/udc/*/srp` signals resume if the PC allowed the D200 to wake it. `deckd` does that on a key press.

**USB Ethernet:** the D200 is `d200-<serial>.local` over mDNS, where `<serial>` is its USB serial number (the CPU
serial, lowercase); debug builds: `ssh root@d200-<serial>.local`. Each D200 has its own addresses, derived from the
serial so several D200s on one PC don't clash. `deckd usb-net` computes them (d200-deck's
[`netid`](https://github.com/riptidewave93/d200-deck/tree/main/netid)) for `S30usb-gadget`:

- IPv4: a `/30` in `198.18.0.0/15`. The D200 is the first address; its DHCP server gives the PC the second, with no
  gateway and no DNS, so the PC keeps its normal network.
- IPv6: a ULA `/64`. The D200 is `::1`; its router advertisements let the PC pick its own address, with router
  lifetime 0 (no default route through the D200).
- Without a CPU serial: `172.31.254.1/30`, IPv4 only.
- `net4` in the settings replaces the IPv4 `/30`.

Sandboxed apps on Linux (e.g. Flatpak browsers) often can't resolve `.local` names, so the PC app opens the
D200's IPv4 address, not its mDNS name.

Proxy tools in "fake-IP" mode (Clash, sing-box, Surge) use `198.18.0.0/15` too; only the D200's own 4 addresses are
affected, and `net4` moves them elsewhere. Both MAC addresses are derived from the CPU serial, so they stay the same
across boots.

**Every OUT endpoint must always have a reader on the D200.** The controller has a single RX FIFO for all of them
([hardware.md](hardware.md#usb)), so data sent to a function nobody reads blocks it and stalls every function, USB
Ethernet included. NCM and mass storage always read theirs, and both HID functions take output reports over the
control endpoint instead of an OUT endpoint. For the same reason there is no USB serial port: a PC probing it for a
modem would stall everything.

## Display and keys

| Item | Value |
|---|---|
| Display | `/dev/dri/card0` (driver `rockchip`), one DPI connector, one mode: 720x1280 at ~36 Hz |
| Orientation | The panel is portrait, mounted in a landscape device: the connector's `panel orientation` property is **Right Side Up**. The kernel does not rotate; userspace draws rotated |
| Buffers | KMS dumb buffers (XRGB8888, ~3.5 MiB each) from a 12 MiB CMA area: no IOMMU on the VOP |
| Console | None on the screen (no fbdev, no fbcon). The U-Boot logo goes away when the display driver loads; the screen stays dark until a program sets a mode |
| Panel | Generic `rockchip,cmd-panel` driver, reading the same panel node as U-Boot ([hardware.md](hardware.md#display)) |
| Keys | `/dev/input/event0` ("keypad"), one press/release per key, no autorepeat |

Key codes, in reading order (as seen from the front):

| Keys | Codes |
|---|---|
| 0-4 (top row) | `KEY_F13`..`KEY_F17` |
| 5-9 (middle row) | `KEY_F18`..`KEY_F22` |
| 10-11 (bottom row) | `KEY_F23`, `KEY_F24` |
| 12 (bottom row) | `KEY_PROG1` |
| 13 (wide bottom-right key) | `KEY_PROG2` |

Quick checks (debug builds): `modetest -M rockchip -c` (connectors and properties), `hexdump -C /dev/input/event0` (press keys).
