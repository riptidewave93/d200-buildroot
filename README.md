# d200-buildroot

A Buildroot br2-external for the **Ulanzi D200** stream controller (Rockchip RK3308B-S, 128 MiB DDR3, 256 MiB SPI
NAND, 720x1280 RGB panel behind the keys). It builds mainline U-Boot, a minimal mainline Linux and a small BusyBox
root filesystem, all flashed over USB with fastboot.

## Docs

- New here? [Install](docs/install.md): back up the stock firmware, then flash.
- [Update](docs/update.md) a D200 that already runs this firmware.
- [Recovery](docs/recovery.md) when it doesn't start.
- Hardware, U-Boot, Linux and A/B updates: [docs/README.md](docs/README.md).

## Status

| Part | State |
|---|---|
| U-Boot | Boots from SPI NAND, boot screens on the display, fastboot flashing, recovery keys (fastboot, maskrom) |
| Linux | Boots in ~3 s. A/B updates from a web page with automatic rollback ([update](docs/update.md)). Read-only root, settings in `/data`. Display, keys, CPU scaling with thermal throttling. Over USB-C: keyboard (HID), config channel, USB Ethernet (`d200-<serial>.local`), read-only USB drive ([details](docs/linux.md#usb)) |
| Key app | [`deckd`](https://github.com/riptidewave93/d200-deck): pages of buttons, media keys, key combos and macros over USB HID. Set up from the [configuration website](https://riptidewave93.github.io/d200-configure/); [`deckhost`](https://github.com/riptidewave93/d200-deck/blob/main/docs/deckhost.md), the PC helper, runs on Linux and Windows |
| Not done | Testing a key press waking the PC from sleep, our own USB VID:PID (optional) ([to do](docs/todo.md)) |

## The D200 project

| Repo | What |
|---|---|
| [d200-buildroot](https://github.com/riptidewave93/d200-buildroot) | The firmware: U-Boot, Linux, the root filesystem; installing, updating, recovery |
| [d200-deck](https://github.com/riptidewave93/d200-deck) | `deckd` (keys and update page on the device), `deckhost` (the PC helper), the config format and USB API |
| [d200-configure](https://github.com/riptidewave93/d200-configure) | The configuration website: https://riptidewave93.github.io/d200-configure/ |

## Versions

| Component | Version |
|---|---|
| Buildroot | `master` at [`d04496c8c14a`](https://gitlab.com/buildroot.org/buildroot/-/commit/d04496c8c14a84c6ff9f23a023eb70eea61c683a) (`BUILDROOT_VER` in `Makefile`) |
| U-Boot | [v2026.10](https://source.denx.de/u-boot/u-boot/-/tree/v2026.10) + `board/ulanzi/d200/patches/uboot/2026.10/` |
| Linux | [v7.2.11](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tag/?h=v7.2.11) + `board/ulanzi/d200/patches/linux/7.2.11/`, config `board/ulanzi/d200/linux.config` |
| rkbin (BL31 v2.28, DDR init v2.11 589 MHz, `boot_merger`) | [`3e288fe814e0`](https://github.com/rockchip-linux/rkbin/commit/3e288fe814e059dd06833495f845cab04ac20a5c) (`BR2_PACKAGE_D200_RKBIN_VERSION`) |

## Building

You need Docker, `make` and `git`. The build runs in a Debian container (`depends/builder.Dockerfile`) as your user:
```bash
make build                # release image
make build FLAVOR=debug   # debug image
```
Update bundles are signed if `D200_SIGNING_KEY` holds a signing key ([ota.md](docs/ota.md#signing)); unsigned ones
install too.

| Flavour | Differences |
|---|---|
| `release` (default) | No SSH and no shell on the UART; U-Boot boots without a console prompt (and falls back to fastboot) |
| `debug` | Root shell on the UART and SSH/SFTP over USB Ethernet (root, no password), `modetest`, the normal U-Boot console |

Both flavours have the recovery keys. The first build takes a while (toolchain, kernel, Go). Images land in
`output/<date>-<flavour>/`; the last 3 builds of each flavour are kept (`KEEP=<n>`, `KEEP=0` keeps all). See
[flashing.md](docs/flashing.md#images) for what each file is.

Other targets:
```
make linux-rebuild   # rebuild one package from scratch and collect the images, e.g. after changing
                     # its patches or config (works for any package: uboot-rebuild, busybox-rebuild, ...;
                     # add FLAVOR=debug for the debug build)
make shell           # shell in the builder container (Buildroot is in BuildEnv/buildroot)
make clean           # remove BuildEnv/ and output/
make reset           # clean + remove the download cache (preserve/) and the builder image
```

## Layout

```
configs/ulanzi_d200_defconfig      Buildroot defconfig
board/ulanzi/d200/
  patches/uboot/2026.10/           U-Boot patch series
  patches/linux/7.2.11/            kernel patches
  patches/mdnsd/1.2/               mdnsd fix (IPv6 mDNS before the PC brings the link up)
  linux.config                     kernel config
  *.fragment                       BusyBox additions, release U-Boot and debug image settings
  rootfs-overlay/                  files added to the root filesystem (init scripts, SSH settings)
  usb-drive/, usb-drive-readme.py  the read-only USB drive and its filled-in README
  kernel.its, ubinize.cfg          kernel FIT and UBI image layouts
  idb-layout.py                    lays out idbloader.img for power-cut-safe updates
  logo/                            boot and fastboot screens (BMPs) and their generator
  flash-fastboot.sh                host flashing script (copied next to the images)
  post-build.sh, post-image.sh     build the USB drive, USB loader, kernel.itb, ubi.img and update bundle
package/d200-rkbin/                rkbin at a selectable commit
package/d200-utils/                reboot-to
package/d200-deck/                 deckd, the key app and update page (Go, from d200-deck)
external.mk                        reproducible U-Boot and kernel, U-Boot boot screens
depends/, scripts/                 builder image and build scripts
docs/                              documentation
```

## License

GPL-2.0-or-later, like Buildroot; see [LICENSE](LICENSE). The Linux and U-Boot patches are under the licenses of the
files they change. The rkbin blobs (downloaded at build time) are Rockchip's and proprietary.
