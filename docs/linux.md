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
  tree (the same DT files U-Boot uses, [u-boot.md](u-boot.md#patches)), and a DWC2 fix so the gadget survives the
  PC sleeping.
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
| `S30usb-gadget` | USB functions; USB Ethernet addresses, DHCP server (udhcpd) and IPv6 router advertisements (radvd); the hostname `d200-<serial>` |
| `S50dropbear` | Debug builds only. SSH server on USB Ethernet (the only network); root without a password. Includes SFTP, so `scp`/`sftp` work |
| `S50mdnsd` | mDNS on USB Ethernet: answers for `d200-<serial>.local` and advertises the web server (`_http._tcp`), plus SSH in debug builds |
| `S60deckd` | `deckd`, the key app ([d200-deck](https://github.com/riptidewave93/d200-deck), packaged in `package/d200-deck`), config in `/data/deckd`. Work in progress |
| syslogd, klogd | BusyBox defaults. Logs go to `/var/log/messages`, in RAM (`/var/log` is `/tmp`), about 400 KB at most |

Files added to Buildroot's default skeleton live in `board/ulanzi/d200/rootfs-overlay/`.

The root filesystem is read-only. Everything kept across boots lives in `/data` (UBIFS, 100 MiB): the key app's
config, the random seed (`/data/seedrng`), the SSH host key (debug builds, `/etc/dropbear` links to
`/data/dropbear`), and an incoming update (`/data/update`). The U-Boot env (slot and update state) is read and
written with `fw_printenv` / `fw_setenv`.

**Flash writes** are kept rare to spare the SPI NAND. Logs, leases and PID files live in RAM (`/tmp`, `/run`), and
UBIFS doesn't update access times (`UBIFS_ATIME_SUPPORT` is off), so reading files writes nothing. What does write:
the random seed (at boot and shutdown), UBI's fastmap (once per boot), the SSH host key (debug builds, once),
config changes, and updates. UBI spreads erases over all blocks and handles bad blocks.

`reboot-to [normal|fastboot|maskrom]` (`package/d200-utils`) reboots into a boot mode: `fastboot` makes U-Boot start
fastboot, `maskrom` makes the BootROM enter USB download mode, `normal` (the default) just reboots.

## USB

The USB-C port is one composite device, `1d6b:0104` "Ulanzi D200", whose USB serial number is the CPU serial.
Functions are set in `/etc/default/usb-gadget`:

| Function | PC sees | D200 side |
|---|---|---|
| `hid` | Keyboard, media keys, system control, mouse | `/dev/hidg0`. `deckd` provides the report descriptor and sends the reports; without it the function is skipped |
| `raw` | A vendor HID device (usage page `0xFFD2`): the config channel for the website (WebHID) and the PC app | `/dev/hidg1`, served by `deckd` |
| `ncm` | USB Ethernet (built-in driver on Linux, macOS, Windows 10/11) | `usb0`, addresses below |
| `msc` | Read-only USB drive "D200 DECK" with a README | `/usr/share/d200/usb-drive.img`, built from `board/ulanzi/d200/usb-drive/` |

The order is the interface order, and it is fixed: always-on functions first, the drive last, so turning the drive off
renumbers nothing. `bcdDevice` is the USB layout version.

**USB Ethernet:** the D200 is `d200-<serial>.local` over mDNS, where `<serial>` is its USB serial number (the CPU
serial, lowercase); debug builds: `ssh root@d200-<serial>.local`. Each D200 has its own addresses, derived from the
serial so several D200s on one PC don't clash (the same scheme as `netid` in d200-deck):

- IPv4: a `/30` in `198.18.0.0/15`. The D200 is the first address; its DHCP server gives the PC the second, with no
  gateway and no DNS, so the PC keeps its normal network.
- IPv6: a ULA `/64`. The D200 is `::1`; its router advertisements let the PC pick its own address, with router
  lifetime 0 (no default route through the D200).
- Without a CPU serial: `172.31.254.1/30`, IPv4 only.

Sandboxed apps on Linux (e.g. Flatpak browsers) often can't resolve `.local` names, so the PC app opens the
D200's IPv4 address, not its mDNS name.

Proxy tools in "fake-IP" mode (Clash, sing-box, Surge) use `198.18.0.0/15` too; only the D200's own 4 addresses are
affected. Both MAC addresses are derived from the CPU serial, so they stay the same across boots.

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
