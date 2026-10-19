# d200-buildroot

A Buildroot br2-external for the **Ulanzi D200** stream controller (Rockchip RK3308B-S, 128 MiB DDR3, 256 MiB SPI
NAND, 720x1280 RGB panel behind the keys). It builds mainline U-Boot, a minimal mainline Linux and a small BusyBox
root filesystem, all flashed over USB with fastboot.

**New here?** Start with [docs/install.md](docs/install.md). Back up the stock firmware first.

## Status

| Part | State |
|---|---|
| U-Boot | Boots from SPI NAND, boot screens on the display, fastboot flashing, recovery keys (fastboot, maskrom) |
| Linux | Boots in ~3 s from UBI. Display, keys, CPU scaling (408-816 MHz) with thermal throttling. Over the USB-C cable: a USB keyboard (HID), the config channel (vendor HID), USB Ethernet (per-device addresses, `d200-<serial>.local`) and a read-only USB drive |
| Key app | [`deckd`](https://github.com/riptidewave93/d200-deck): pages of buttons, media keys, key combos and macros over USB HID. The PC app and the config website are in progress |
| Not done | Updates without fastboot, waking the PC from sleep, our own USB VID:PID, Windows ([to do](docs/todo.md)) |

## Versions

| Component | Version |
|---|---|
| Buildroot | `master` at [`d04496c8c14a`](https://gitlab.com/buildroot.org/buildroot/-/commit/d04496c8c14a84c6ff9f23a023eb70eea61c683a) (`BUILDROOT_VER` in `Makefile`), until the next Buildroot release |
| U-Boot | [v2026.10](https://source.denx.de/u-boot/u-boot/-/tree/v2026.10) + `board/ulanzi/d200/patches/uboot/2026.10/` |
| Linux | [v7.2.11](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tag/?h=v7.2.11) + `board/ulanzi/d200/patches/linux/7.2.11/`, config `board/ulanzi/d200/linux.config` |
| rkbin (BL31 v2.28, DDR init v2.11 589 MHz, `boot_merger`) | [`3e288fe814e0`](https://github.com/rockchip-linux/rkbin/commit/3e288fe814e059dd06833495f845cab04ac20a5c) (`BR2_PACKAGE_D200_RKBIN_VERSION`) |

## Building

You need Docker, `make` and `git`. The build runs in a Debian container (`depends/builder.Dockerfile`) as your user:
```bash
make build                # release image
make build FLAVOR=debug   # debug image
```

| Flavour | Differences |
|---|---|
| `release` (default) | No SSH and no shell on the UART; U-Boot boots without a console prompt (and falls back to fastboot) |
| `debug` | Root shell on the UART and SSH/SFTP over USB Ethernet (root, no password), `modetest`, the normal U-Boot console |

Recovery (the fastboot key, the maskrom key combo) works in both. Each flavour builds in its own
`BuildEnv/output-<flavour>/`. The first build takes a while (toolchain, kernel, Go). Images land in
`output/<date>-<flavour>/` (the last 3 of each are kept):

| File | What |
|---|---|
| `flash-fastboot.sh` | Flashes the images below over fastboot ([flashing.md](docs/flashing.md)) |
| `idbloader.img` | TPL (rkbin DDR init) + U-Boot SPL, for the `idbloader` partition |
| `u-boot.itb` | U-Boot FIT (BL31 + U-Boot + DTB), for `u-boot` and `u-boot-backup` |
| `kernel.itb` | Kernel FIT (Image.gz + DTB), for the `kernel` UBI volume |
| `rootfs.ubifs` | Root filesystem, for the `rootfs` UBI volume |
| `ubi.img` | The whole `ubi` partition (`kernel` + `rootfs`), for a full install |
| `d200-usb-loader.bin` | Runs U-Boot from RAM over USB, from maskrom: `rkdeveloptool boot d200-usb-loader.bin` |
| `u-boot-rockchip-usb471.bin`, `-usb472.bin` | The two stages packed into `d200-usb-loader.bin` |
| `d200-full.img` | The whole install as one image, for `rkdeveloptool wl 0` ([install.md](docs/install.md#3-flash)) |
| `rk3308_loader_wo_ftl.bin` | Rockchip's raw NAND loader (rkbin), which `rkdeveloptool` needs to write `d200-full.img` |
| `SHA256SUMS` | Checksums of the above |
| `d200-<version>-<flavour>.tar.gz` | All of the above in one archive, for releases (`<version>` is this repo's `git describe`) |

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
  busybox.fragment                 BusyBox additions
  rootfs-overlay/                  files added to the root filesystem (init scripts, SSH settings)
  usb-drive/                       contents of the read-only USB drive
  kernel.its, ubinize.cfg          kernel FIT and UBI image layouts
  logo/                            boot and fastboot screens (BMPs) and their generator
  flash-fastboot.sh                host flashing script (copied next to the images)
  post-build.sh, post-image.sh     build the USB drive image, the USB loader, kernel.itb and ubi.img
package/d200-rkbin/                rkbin at a selectable commit
package/d200-utils/                reboot-to
package/d200-deck/                 deckd, the key app (Go; source: github.com/riptidewave93/d200-deck)
depends/, scripts/                 builder image and build scripts
docs/                              documentation
```

## Docs

[Install](docs/install.md) · [Flashing](docs/flashing.md) · [Recovery](docs/recovery.md) ·
[Hardware](docs/hardware.md) · [U-Boot](docs/u-boot.md) · [Linux](docs/linux.md) · [all docs](docs/README.md)

## License

GPL-2.0-or-later, like Buildroot; see [LICENSE](LICENSE). The Linux and U-Boot patches are under the licenses of the
files they change. The rkbin blobs (downloaded at build time) are Rockchip's and proprietary.
