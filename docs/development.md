# Development

Building is in the [README](../README.md#building). This page has the rest: make targets, versions and the repo
layout.

## Builds

- The first build takes a while (toolchain, kernel, Go). The builder image is `depends/builder.Dockerfile`.
- Images land in `output/<date>-<flavour>/` ([what each file is](flashing.md#images)). The last 3 builds of each
  flavour are kept (`KEEP=<n>`, `KEEP=0` keeps all).
- Update bundles are signed if `D200_SIGNING_KEY` holds a signing key ([ota.md](ota.md#signing)); unsigned ones
  install too.

Other targets:
```
make linux-rebuild   # rebuild one package from scratch and collect the images, e.g. after changing
                     # its patches or config (works for any package: uboot-rebuild, busybox-rebuild, ...;
                     # add FLAVOR=debug for the debug build)
make shell           # shell in the builder container (Buildroot is in BuildEnv/buildroot)
make clean           # remove BuildEnv/ and output/
make reset           # clean + remove the download cache (preserve/) and the builder image
```

## Versions

| Component | Version |
|---|---|
| Buildroot | `master` at [`d04496c8c14a`](https://gitlab.com/buildroot.org/buildroot/-/commit/d04496c8c14a84c6ff9f23a023eb70eea61c683a) (`BUILDROOT_VER` in `Makefile`) |
| U-Boot | [v2026.10](https://source.denx.de/u-boot/u-boot/-/tree/v2026.10) + `board/ulanzi/d200/patches/uboot/2026.10/` |
| Linux | [v7.2.11](https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/tag/?h=v7.2.11) + `board/ulanzi/d200/patches/linux/7.2.11/`, config `board/ulanzi/d200/linux.config` |
| rkbin (BL31 v2.28, DDR init v2.11 589 MHz, `boot_merger`) | [`3e288fe814e0`](https://github.com/rockchip-linux/rkbin/commit/3e288fe814e059dd06833495f845cab04ac20a5c) (`BR2_PACKAGE_D200_RKBIN_VERSION`) |
| d200-deck | `D200_DECK_VERSION` in `package/d200-deck/d200-deck.mk` |

## Layout

```
configs/ulanzi_d200_defconfig      Buildroot defconfig
board/ulanzi/d200/
  patches/uboot/2026.10/           U-Boot patch series
  patches/linux/7.2.11/            kernel patches
  patches/mdnsd/1.2/               mdnsd fix
  linux.config                     kernel config
  *.fragment                       BusyBox additions, release U-Boot and debug image settings
  rootfs-overlay/                  files added to the root filesystem
  usb-drive/, usb-drive-readme.py  the read-only USB drive and its filled-in README
  kernel.its, ubinize.cfg          kernel FIT and UBI image layouts
  idb-layout.py                    lays out idbloader.img
  logo/                            boot and fastboot screens (BMPs) and their generator
  flash-fastboot.sh                host flashing script (copied next to the images)
  post-build.sh, post-image.sh     build the USB drive, USB loader, kernel.itb, ubi.img and update bundle
package/d200-rkbin/                rkbin at a selectable commit
package/d200-utils/                reboot-to
package/d200-deck/                 deckd, the key app and update page (from d200-deck)
external.mk                        reproducible U-Boot and kernel builds, U-Boot boot screens
depends/, scripts/                 builder image and build scripts
```
