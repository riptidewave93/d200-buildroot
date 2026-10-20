# U-Boot

Mainline U-Boot **v2026.10** plus the patches in `board/ulanzi/d200/patches/uboot/2026.10/`, built by Buildroot
(defconfig `ulanzi-d200-rk3308`). BL31 and the DDR init (TPL) come from rkbin via the `d200-rkbin` package.

What the D200 does at boot:
1. SPL checks the maskrom keys first, then loads `u-boot.itb` from `u-boot`, falling back to `u-boot-backup`, then to
   maskrom.
2. U-Boot reads the CPU serial, shows the boot screen and offers the fastboot key for 1.5 s.
3. It boots Linux from slot A or B, and the other slot if that fails ([ota.md](ota.md#boot)).

The console is on the UART, and only in debug builds. Release builds (`board/ulanzi/d200/uboot-release.fragment`)
boot without a prompt, and wait in fastboot if Linux doesn't boot. The screen only ever shows the boot screens.

The D200 device tree files are the same in U-Boot and Linux. Default env: `board/ulanzi/d200/ulanzi-d200.env` in the
U-Boot tree.

## Boot screens

Pre-rendered BMPs in `board/ulanzi/d200/logo/`, made by `d200-boot-logo.py` (`boot` and `fastboot` modes).
`external.mk` copies them into the U-Boot tree after patching. A custom splash without rebuilding:
[flashing.md](flashing.md#custom-boot-screen).

## Working on the patches

```bash
git clone --depth 1 --branch v2026.10 https://source.denx.de/u-boot/u-boot.git
cd u-boot && git switch -c d200
git am <repo>/board/ulanzi/d200/patches/uboot/2026.10/*.patch
# ... edit, commit (one topic per patch, git commit -s) ...
rm <repo>/board/ulanzi/d200/patches/uboot/2026.10/*.patch    # so renamed patches don't leave old files
git format-patch --no-signature --zero-commit -N -o <repo>/board/ulanzi/d200/patches/uboot/2026.10 v2026.10..d200
```
Then `make uboot-rebuild` in this repo rebuilds U-Boot with the new patches. The Linux patches work the same way
(tag `v7.2.11`, `board/ulanzi/d200/patches/linux/7.2.11`, `make linux-rebuild`). The D200 device tree is in both
series and must stay identical.
