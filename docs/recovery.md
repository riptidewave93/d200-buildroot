# Recovery

How to get a D200 back to a working state, easiest first. Most methods end with flashing over USB-C with
`flash-fastboot.sh` from a build's `output/<date>-<flavour>/` folder ([flashing.md](flashing.md)).

You need `fastboot` (Android platform tools) and, for maskrom, `rkdeveloptool`.

| What's broken | Use |
|---|---|
| A bad update | Nothing: U-Boot goes back to the previous slot by itself ([ota.md](ota.md#boot)) |
| Linux (U-Boot still starts) | [1.1 Fastboot key](#11-fastboot-key) |
| U-Boot proper | [1.2 Maskrom keys](#12-maskrom-keys) or [1.3 automatic maskrom](#13-automatic-maskrom) |
| SPL / IDB (nothing on screen, keys don't reach maskrom) | [3. Hardware short](#3-hardware-short-last-resort) |
| You want the stock firmware back | [4. Restore the stock firmware](#4-restore-the-stock-firmware) |

## 1. Without a UART

### 1.1 Fastboot key
From a debug build's shell (SSH or UART): `reboot-to fastboot`. Or hold the **top-left key** while the board boots: it
is labelled "Hold for Fastboot" for 1.5 s, and holding it switches the screen to a USB plug and "Fastboot". Then:
```bash
fastboot devices          # shows the board's serial
./flash-fastboot.sh       # see flashing.md for the options
```

### 1.2 Maskrom keys
From a debug build's shell: `reboot-to maskrom`. Or hold the **top-left and bottom-left keys** while plugging in USB-C.
SPL checks them first thing, before DRAM and the NAND are set up, so this works even when U-Boot proper is broken. The screen stays dark.

Then run U-Boot from RAM and continue as in 1.1:
```bash
rkdeveloptool list                           # "Maskrom"
rkdeveloptool boot d200-usb-loader.bin       # while holding the top-left key
./flash-fastboot.sh
```
`d200-usb-loader.bin` doesn't write anything to the flash by itself.

### 1.3 Automatic maskrom
If SPL can't load U-Boot from either `u-boot` or `u-boot-backup`, it enters maskrom by itself. Continue as in 1.2.

## 2. With a UART

Connect a 3.3 V UART to UART2 (TX GPIO4_D2, RX GPIO4_D3, GND) at 1500000 8N1. The U-Boot prompt and Ctrl-B only
exist in debug builds; a release build only prints its boot log.

| Method | How |
|---|---|
| U-Boot prompt | Press a key during "Hit any key to stop autoboot" |
| Fastboot | At the prompt: `fastboot usb 0` (Ctrl-C to stop) |
| Maskrom from U-Boot | At the prompt: `maskrom` |
| Maskrom from SPL | Hold or repeat **Ctrl-B** while powering on (SPL checks during its first 100 ms). Works when U-Boot proper is broken |

Flashing over the UART alone (slow, for when USB is unusable): load each file with `loady <addr>`, then
`mtd erase` / `mtd write` it to the partitions in [flashing.md](flashing.md#nand-layout). Write `idbloader-x4.img`
(all four IDB copies) at `0x0`, without skipping bad blocks.

## 3. Hardware short (last resort)

For when SPL/IDB itself is broken, so neither the keys nor Ctrl-B work. The short stops the BootROM from reading the
flash, so it falls back to maskrom.

1. **Unplug the UART adapter.** It back-powers the SoC through TX, and then the BootROM doesn't start fresh.
2. Hold one of these shorts:
   - **R9602**: the pad nearest the SoC to GND (a mounting screw works). This is Ulanzi's documented method.
   - **SPI NAND** (WSON-8): **pin 1 (CS#) to pin 8 (VCC)**. They are adjacent. Never bridge VCC to GND.
3. Plug in USB-C while holding the short. Release once `lsusb` shows `2207:330e` (or `rkdeveloptool list` says
   "Maskrom").
4. Continue as in [1.2](#12-maskrom-keys).

## 4. Restore the stock firmware

This needs the backup you made before installing ([install.md](install.md#1-back-up-the-stock-firmware)) and the
stock Rockchip loader, built from [rkbin](https://github.com/rockchip-linux/rkbin):
```bash
git clone --depth 1 https://github.com/rockchip-linux/rkbin && cd rkbin
./tools/boot_merger RKBOOT/RK3308MINIALL.ini     # -> rk3308_loader_v*.bin
```
Then enter maskrom (sections 1-3) and:
```bash
sha256sum -c d200-factory.img.sha256
rkdeveloptool boot rk3308_loader_v*.bin
rkdeveloptool ef                                 # erase everything, so the stock flash layer starts fresh
rkdeveloptool write 0 d200-factory.img
rkdeveloptool reset
```
This procedure is untested on a board that has run this firmware.
