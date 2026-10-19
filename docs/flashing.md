# Flashing

Updates are flashed over USB-C with fastboot. Coming from the stock firmware? See [install.md](install.md) first.

To get the board into fastboot: run `reboot-to fastboot` on it (debug builds, over SSH or the UART), or hold the **top-left key**
while it boots. If neither works, see [recovery.md](recovery.md).

## NAND layout

| Offset | Size | Partition | Contents |
|---|---|---|---|
| `0x000000` | 1 MiB | `idbloader` | 4 copies of `idbloader.img` (rkbin DDR init + SPL), one every 256 KiB |
| `0x100000` | 4 MiB | `u-boot` | `u-boot.itb` (BL31 + U-Boot + DTB) |
| `0x500000` | 4 MiB | `u-boot-backup` | `u-boot.itb` again; SPL falls back to it |
| `0x900000` | 246 MiB | `ubi` | UBI (LEB 126976 B, fastmap) |
| `0xff00000` | 1 MiB | (none) | Left unused: Rockchip's loader keeps these blocks and `rkdeveloptool ef` doesn't erase them |

UBI volumes:

| Volume | Contents |
|---|---|
| `env`, `env_r` | U-Boot environment (redundant copies, created on the first `saveenv`) |
| `splash` | Optional custom boot screen (see below) |
| `kernel` | Linux FIT image with the kernel and device tree (`kernel.itb`) |
| `rootfs` | Root filesystem, UBIFS (`rootfs.ubifs`) |

## Flashing

From a build's `output/<date>-<flavour>/` folder, with the board in fastboot:
```bash
./flash-fastboot.sh                    # full install: U-Boot + the whole UBI partition (ubi.img), then reboot
./flash-fastboot.sh --uboot            # only U-Boot: idbloader, u-boot, u-boot-backup (~2 s)
./flash-fastboot.sh --linux            # only Linux: kernel.itb -> "kernel", rootfs.ubifs -> "rootfs"
./flash-fastboot.sh --splash my.bmp    # also set a custom boot screen
./flash-fastboot.sh --no-reboot        # stay in fastboot afterwards
```
A full install resets the U-Boot environment and removes a custom splash. `--linux` keeps both. It creates missing
volumes with the same sizes as `ubi.img` (`kernel` 16 MiB, `rootfs` 160 MiB), which leaves ~55 MiB for others.

A saved U-Boot environment overrides new defaults (such as the boot command). After a U-Boot update that changes
them, reset it once:
```bash
fastboot -- oem run:env default -a    # "--" stops fastboot from parsing -a itself
fastboot oem run:saveenv
```

## Fastboot reference

Partition names are looked up on the board: the MTD partitions above, anything else is a UBI volume: `myvol`, or
`ubi:myvol` (`<mtd-partition>:<volume>`). Bad blocks are skipped. Images are limited to 32 MiB (the
download buffer); sparse images aren't supported.

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
fastboot oem run:ubi create splash <size> static
fastboot flash splash my.bmp
```
Remove it with `fastboot oem run:ubi remove splash`. The "Hold for Fastboot" label is part of the built-in logo, so
it isn't drawn over a custom splash, but the key still works.
