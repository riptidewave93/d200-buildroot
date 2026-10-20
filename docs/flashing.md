# Flashing

`flash-fastboot.sh`, fastboot by hand, the build's images and the NAND layout. For the usual ways to update, see
[update.md](update.md). To get the board into fastboot, see [recovery.md](recovery.md#11-fastboot-key).

## NAND layout

| Offset | Size | Partition | Contents |
|---|---|---|---|
| `0x000000` | 1 MiB | `idbloader` | 4 copies of `idbloader.img` (rkbin DDR init + SPL), one every 256 KiB. Each copy is two NAND blocks: the header alone in the first, TPL + SPL in the second |
| `0x100000` | 4 MiB | `u-boot` | `u-boot.itb` (BL31 + U-Boot + DTB) |
| `0x500000` | 4 MiB | `u-boot-backup` | `u-boot.itb` again; SPL falls back to it |
| `0x900000` | 246 MiB | `ubi` | UBI (LEB 126976 B, fastmap) |
| `0xff00000` | 1 MiB | (none) | Left unused: Rockchip's loader keeps these blocks and `rkdeveloptool ef` doesn't erase them |

UBI volumes (fixed IDs):

| ID | Volume | Type | Size | Contents |
|---|---|---|---|---|
| 0, 1 | `env`, `env_r` | dynamic | 124 KiB each | U-Boot environment (redundant copies) |
| 2, 3 | `kernel_a`, `kernel_b` | static | 8 MiB each | Linux FIT image with the kernel and device tree (`kernel.itb`), slot A and B |
| 4, 5 | `rootfs_a`, `rootfs_b` | dynamic | 32 MiB each | Root filesystem, UBIFS (`rootfs.ubifs`), mounted read-only |
| 6 | `data` | dynamic | 100 MiB | `/data`: settings and the incoming update |
| 7 | `splash` | static | its image | Optional custom boot screen (see below) |

A fresh install fills slot A; the first update creates and fills slot B. How updates use the slots is in
[ota.md](ota.md).

## Flashing

In the [image folder](install.md#before-you-start), with the board in fastboot:
```bash
./flash-fastboot.sh                    # full install: U-Boot + the whole UBI partition (ubi.img), then reboot
./flash-fastboot.sh --uboot            # only U-Boot: idbloader, u-boot, u-boot-backup (~2 s)
./flash-fastboot.sh --linux            # only Linux, into slot A (kernel_a, rootfs_a)
./flash-fastboot.sh --splash my.bmp    # also set a custom boot screen
./flash-fastboot.sh --no-reboot        # stay in fastboot afterwards
```
A full install resets the U-Boot environment, `/data` (settings) and a custom splash. `--linux` keeps them, and
makes the board boot slot A. It creates missing volumes with the sizes above.

The saved U-Boot environment holds only the A/B variables; everything else comes with U-Boot, so `--uboot` also
updates the defaults ([ota.md](ota.md#boot)).

## Images

What a build puts in `output/<date>-<flavour>/`:

| File | What |
|---|---|
| `flash-fastboot.sh` | Flashes the images below over fastboot ([Flashing](#flashing)) |
| `idbloader.img` | TPL (rkbin DDR init) + U-Boot SPL: one 256 KiB copy (the update bundle carries this) |
| `idbloader-x4.img` | The `idbloader` partition: 4 copies of `idbloader.img`, one every 256 KiB |
| `u-boot.itb` | U-Boot FIT (BL31 + U-Boot + DTB), for `u-boot` and `u-boot-backup` |
| `kernel.itb` | Kernel FIT (Image.gz + DTB), for the `kernel_a` / `kernel_b` UBI volumes |
| `rootfs.ubifs` | Root filesystem, for the `rootfs_a` / `rootfs_b` UBI volumes |
| `ubi.img` | The whole `ubi` partition (env, slot A, empty `/data`), for a full install |
| `d200-usb-loader.bin` | Runs U-Boot from RAM over USB, from maskrom: `rkdeveloptool db d200-usb-loader.bin` |
| `u-boot-rockchip-usb471.bin`, `-usb472.bin` | The two stages packed into `d200-usb-loader.bin` |
| `d200-full.img` | The whole install as one image, for `rkdeveloptool wl 0` ([install.md](install.md#3-flash)) |
| `rk3308_loader_wo_ftl.bin` | Rockchip's raw NAND loader (rkbin), which `rkdeveloptool` needs to write `d200-full.img` |
| `d200-<version>-<flavour>-update.tar` | Update bundle for the update page ([update.md](update.md), [ota.md](ota.md#bundle)) |
| `d200-<version>-<flavour>.zip` | The fastboot set (everything above `d200-full.img`, with its own `SHA256SUMS`), for releases |
| `d200-<version>-<flavour>-maskrom.tar.xz` | `d200-full.img` and `rk3308_loader_wo_ftl.bin`, for releases |
| `SHA256SUMS` | Checksums of the above |

`<version>` is this repo's `git describe`; a release (tag `vX.Y.Z`) attaches the `.zip`, `-maskrom.tar.xz` and
`-update.tar` of both flavours.

## Fastboot reference

Partition names are looked up on the board. The MTD partitions above are flashed directly; any other name is a UBI
volume (`myvol`, or `ubi:myvol`). Bad blocks are skipped, except in `idbloader`: its copies must stay at their
offsets, so it is written block for block, last block first. Images are limited to 32 MiB (the download buffer);
sparse images aren't supported.

```bash
fastboot getvar partition-size:u-boot
fastboot flash u-boot u-boot.itb
fastboot oem run:ubi create myvol 0x100000 dynamic     # volumes are made with U-Boot's ubi command
fastboot flash myvol file.bin
fastboot erase myvol                                   # empties a volume / erases a partition
fastboot oem run:ubi remove myvol
fastboot oem run:<any U-Boot command>                  # e.g. oem run:maskrom
fastboot oem console                                   # output of the last oem run
fastboot continue                                      # leave fastboot and boot
fastboot reboot
```

## Custom boot screen

If the UBI volume `splash` holds a BMP (8/24/32 bpp, RLE8 ok, up to 8 MiB), U-Boot shows it centred on the 1280x720
screen instead of the built-in logo. Design it around the key windows in [hardware.md](hardware.md#screen-layout).
```bash
./flash-fastboot.sh --splash my.bmp --no-reboot     # or by hand:
fastboot oem run:ubi create splash <size> static 7
fastboot flash splash my.bmp
```
Remove it with `fastboot oem run:ubi remove splash`. The "Hold for Fastboot" label is part of the built-in logo, so
it isn't drawn over a custom splash, but the key still works.
