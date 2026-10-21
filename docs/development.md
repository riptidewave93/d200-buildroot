# Development

Building is in the [README](../README.md#building). This page has the rest: make targets, contributing and releases,
versions and the repo layout.

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
make check           # quick checks without a full build, as CI runs them (check-lint, -config, -patches)
make shell           # shell in the builder container (Buildroot is in BuildEnv/buildroot)
make clean           # remove BuildEnv/ and output/
make reset           # clean + remove the download cache (preserve/) and the builder image
```

## Contributing and releases

- Every change is a pull request, squash-merged. Its title becomes the commit on `main` and its line in the release
  notes, and must be a [conventional commit](https://www.conventionalcommits.org/), such as `feat(deck): …`,
  `fix(linux): …` or `docs: …`; a check enforces it.
- CI runs `make check` on every pull request and push to `main`, and a full release build on `main` and on pull
  requests that change what goes into the image.
- [Release Drafter](https://github.com/release-drafter/release-drafter) keeps a draft release up to date with the
  pull requests merged to `main` (Features, Fixes, Other) and the next version: `feat` raises the minor version,
  everything else the patch version, and below 1.0 a breaking change (`feat!: …`) raises the minor version.
- To release, run the **Release** workflow on `main` (Actions → Release → Run workflow). It builds both flavours
  with the draft's version (or the one you give) and signs the update bundles, then tags `main`, attaches the files
  with `SHA256SUMS` to the draft and publishes it. If that last part fails, the tag is removed and the draft stays a
  draft. **Dry run** builds, collects and checks the files (signed bundles, `SHA256SUMS`) and stops before the tag;
  the files stay as artifacts.
- Versions: major for a change older pieces can't handle (a new minimum protocol, a config format break, a higher
  `min_updater`), minor for a feature, patch for a fix.
- The version on the D200 and in the file names is `git describe`: `vX.Y.Z` for a release, `vX.Y.Z-<n>-g<commit>`
  for a build after it.
- Renovate opens a pull request when d200-deck releases (`D200_DECK_VERSION`), and one a week for GitHub Actions.

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
  d200-install.py                  installs d200-full.img from maskrom (also copied next to the images)
  post-build.sh, post-image.sh     build the USB drive, USB loader, kernel.itb, ubi.img and update bundle
package/d200-rkbin/                rkbin at a selectable commit
package/d200-utils/                reboot-to
package/d200-deck/                 deckd, the key app and update page (from d200-deck)
external.mk                        reproducible U-Boot and kernel builds, U-Boot boot screens
depends/, scripts/                 builder image and build scripts
```
