# U-Boot

Mainline U-Boot **v2026.10** plus the patch series in `board/ulanzi/d200/patches/uboot/2026.10/`, built by Buildroot
(defconfig `ulanzi-d200-rk3308`). BL31 and the DDR init (TPL) come from rkbin via the `d200-rkbin` package.

What the board does at boot:
1. SPL: checks the maskrom key combo (and Ctrl-B in debug builds), then loads `u-boot.itb` from `u-boot`, falling back to
   `u-boot-backup`, falling back to maskrom.
2. U-Boot: reads the CPU serial from OTP, shows the boot screen, offers the fastboot key for 1.5 s.
3. Boots Linux: `ubi read` the FIT image from the `kernel` UBI volume, `bootm` it.

The console is the UART only, and only in debug builds. Release builds (`board/ulanzi/d200/uboot-release.fragment`)
boot without a prompt, and wait in fastboot if Linux doesn't boot. The panel sits behind the keys, so it only shows
the boot screens.

## Patches

| # | Patch | Why |
|---|---|---|
| 1 | clk: rockchip: rk3308: add SCLK_SFC support | The SPI NAND controller's clock was missing |
| 2 | spl: add a minimal SPI NAND loader | SPL has to load U-Boot from SPI NAND; no small loader existed |
| 3 | rockchip: spl: support booting from SPI NAND | Boot-device mapping for the above |
| 4 | rockchip: add 'maskrom' command | Reboot into maskrom from the prompt |
| 5 | rockchip: spl: add optional fallback to maskrom mode | No bootable U-Boot → maskrom instead of hanging |
| 6 | rockchip: spl: add optional Ctrl-B to enter maskrom mode | Maskrom from the UART at power-on |
| 7 | rockchip: rk3308: hand the OTP to the non-secure controller on RK3308B-S | See [hardware.md](hardware.md#otp-cpu-id--serial) |
| 8 | misc: rockchip-otp: add RK3308B-S support | The B-S OTP controller → `serial#`, `cpuid#` |
| 9 | fastboot: add MTD and UBI flash backend | Fastboot could not flash SPI NAND or UBI volumes |
| 10 | arm64: dts: rockchip: rk3308: add VOP and LCDC pinctrl | Display controller node (missing upstream) |
| 11 | video: rockchip: add RK3308 VOP driver | VOP lite driver, incl. software rotation for the rotated panel |
| 12 | video: add a command-sequence panel driver | Panels described with the Rockchip vendor DT properties (init sequence over bit-banged SPI) |
| 13 | arm64: dts: rockchip: add RK3308B-S SoC variant | RK3308B-S operating points and TSADC (used by Linux) |
| 14 | arm64: dts: rockchip: add Ulanzi D200 | Board DT: console, NAND partitions, display, backlight, watchdog, USB, `vdd_core` |
| 15 | board: rockchip: add Ulanzi D200 | Board target and defconfig: env in UBI, fastboot, display probe, optional UBI splash, boot command |
| 16 | board: ulanzi: d200: add a key combination to enter maskrom from SPL | Top-left + bottom-left keys → maskrom |
| 17 | board: ulanzi: d200: hold the top-left key to enter fastboot | "Hold for Fastboot" |

Patches 10, 13 and 14 (RK3308 VOP node, RK3308B-S dtsi, D200 device tree) are also Linux patches, so both use the
same DT. U-Boot sets `vdd_core` to 1.015 V at start (`regulator-init-microvolt` in the U-Boot-only dtsi).

## Notes

- **Display.** The panel is portrait (720x1280) but mounted landscape. U-Boot draws into a 1280x720 framebuffer and the
  VOP driver copies it rotated into the scanout buffer on `video_sync`. A full redraw takes ~21 ms (memory-bound).
- **Boot screens** are pre-rendered BMPs made by `board/ulanzi/d200/logo/d200-boot-logo.py` (`boot` and `fastboot`
  modes). Patches can't carry binary files, so `external.mk` copies them into the U-Boot tree after patching:
  `d200-boot-logo.bmp` → `drivers/video/u_boot_logo.bmp`, `d200-fastboot.bmp` → `board/ulanzi/d200/d200_fastboot.bmp`.
- **Watchdog.** It can already be running when U-Boot starts, so the DesignWare watchdog driver is enabled.
- **Environment** lives in UBI (`env`/`env_r`). A saved env overrides new defaults; to reset it, see
  [flashing.md](flashing.md#flashing).
- **RAM.** The fastboot buffer is 32 MiB at `0x02000000`. The kernel FIT loads at `kernel_addr_r` (`0x02080000`);
  U-Boot itself lives above ~`0x046d0000`.

## Working on the patches

```bash
git clone --depth 1 --branch v2026.10 https://source.denx.de/u-boot/u-boot.git
cd u-boot && git switch -c d200
git am <repo>/board/ulanzi/d200/patches/uboot/2026.10/*.patch
# ... edit, commit (one topic per patch) ...
git format-patch --no-signature --zero-commit -N -o <repo>/board/ulanzi/d200/patches/uboot/2026.10 v2026.10..d200
```
Then `make uboot-rebuild` in this repo rebuilds U-Boot with the new patches. The Linux patches work the same way
(tag `v7.2.11`, `board/ulanzi/d200/patches/linux/7.2.11`, `make linux-rebuild`).
