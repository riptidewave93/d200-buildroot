# Flashing

Flashing over USB-C with fastboot, and the NAND layout. For the usual ways to update, see [update.md](update.md);
coming from the stock firmware, see [install.md](install.md) first.

To get the board into fastboot, see [recovery.md](recovery.md#11-fastboot-key).

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

From a build's `output/<date>-<flavour>/` folder, with the board in fastboot:
```bash
./flash-fastboot.sh                    # full install: U-Boot + the whole UBI partition (ubi.img), then reboot
./flash-fastboot.sh --uboot            # only U-Boot: idbloader, u-boot, u-boot-backup (~2 s)
./flash-fastboot.sh --linux            # only Linux, into slot A: kernel.itb -> "kernel_a", rootfs.ubifs -> "rootfs_a"
./flash-fastboot.sh --splash my.bmp    # also set a custom boot screen
./flash-fastboot.sh --no-reboot        # stay in fastboot afterwards
```
A full install resets the U-Boot environment, `/data` (settings) and a custom splash. `--linux` keeps them, and
makes the board boot slot A. It creates missing volumes with the sizes above.

A U-Boot update brings its new default environment with it ([ota.md](ota.md#boot)).

## Fastboot reference

Partition names are looked up on the board: the MTD partitions above, anything else is a UBI volume: `myvol`, or
`ubi:myvol` (`<mtd-partition>:<volume>`). Bad blocks are skipped, except in `idbloader`: its copies must stay at
their offsets, so it is written block for block, last block first. Images are limited to 32 MiB (the download
buffer); sparse images aren't supported.

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
