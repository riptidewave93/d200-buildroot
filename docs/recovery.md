# Recovery

Getting a D200 working again, easiest first. Most ways end with `./flash-fastboot.sh` in the
[image folder](install.md#before-you-start). You need `fastboot` and, for maskrom, `rkdeveloptool`.

| What you see | Use |
|---|---|
| A new version doesn't start properly | Nothing: the D200 goes back to the previous version by itself |
| The boot screen shows, but the keys never come up | [1.1 Fastboot key](#11-fastboot-key). If Linux doesn't start at all, a release build is already waiting in fastboot |
| No boot screen | [1.2 Maskrom keys](#12-maskrom-keys). If `rkdeveloptool ld` already shows "Maskrom", see [1.3](#13-automatic-maskrom) |
| No boot screen, and the maskrom keys don't work | [3. Hardware short](#3-hardware-short-last-resort) |
| You want the stock firmware back | [4. Back to stock](#4-back-to-stock) |

## 1. Without a UART

### 1.1 Fastboot key
From a debug build's shell (SSH or UART): `reboot-to fastboot`. Or hold the **top-left key** while the D200 boots:
it is labelled "Hold for Fastboot" for 1.5 s, and holding it switches the screen to a USB plug and "Fastboot". Then:
```bash
fastboot devices          # shows the D200's serial
./flash-fastboot.sh       # see flashing.md for the options
```

### 1.2 Maskrom keys
From a debug build's shell: `reboot-to maskrom`. Or hold the **top-left and bottom-left keys** while plugging in
USB-C. This works even when U-Boot is broken. The screen stays dark.

Then run U-Boot from RAM and continue as in 1.1:
```bash
rkdeveloptool ld                             # "Maskrom"
rkdeveloptool db d200-usb-loader.bin         # while holding the top-left key
./flash-fastboot.sh
```
`d200-usb-loader.bin` doesn't write anything to the flash by itself.

On Windows, RKDevTool can reinstall from maskrom instead (it erases everything, settings included): see
[install.md](install.md#windows-rkdevtool). Fastboot skips bad NAND blocks; RKDevTool doesn't.

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
| Maskrom from SPL | Hold or repeat **Ctrl-B** while powering on; works when U-Boot is broken |

Flashing over the UART alone (slow, for when USB is unusable): load each file with `loady <addr>`, then
`mtd erase` / `mtd write` it to the partitions in [flashing.md](flashing.md#nand-layout). Write `idbloader-x4.img`
(all four IDB copies) at `0x0`, without skipping bad blocks.

## 3. Hardware short (last resort)

For when neither the keys nor Ctrl-B reach maskrom. The short stops the BootROM from reading the
flash, so it falls back to maskrom.

1. **Unplug the UART adapter.** It back-powers the SoC, and the short then doesn't work.
2. Hold one of these shorts:
   - **R9602**: the pad nearest the SoC to GND (a mounting screw works). This is Ulanzi's documented method.
   - **SPI NAND** (WSON-8): **pin 1 (CS#) to pin 8 (VCC)**. They are adjacent. Never bridge VCC to GND.
3. Plug in USB-C while holding the short. Release once `lsusb` shows `2207:330e` (or `rkdeveloptool ld` says
   "Maskrom").
4. Continue as in [1.2](#12-maskrom-keys).

## 4. Back to stock

Ulanzi's recovery reinstalls the stock firmware with RKDevTool on Windows; it erases everything.
1. Enter maskrom with the [maskrom keys](#12-maskrom-keys) and erase the flash: steps 1-5 of
   [Windows: RKDevTool](install.md#windows-rkdevtool).
2. Unplug the D200 and plug it back in. With the flash erased, it comes up in maskrom.
3. Continue with the **Upgrade Firmware** step of
   [Misyuk-T/ulanzi-d200-recovery](https://github.com/Misyuk-T/ulanzi-d200-recovery) (for the RK3308H3 board, serial
   number starting with "01": [CHADREX/ulanzi-d200-recovery](https://github.com/CHADREX/ulanzi-d200-recovery)).
