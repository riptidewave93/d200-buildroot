# Installing

Replacing the stock firmware takes three steps: back it up, enter maskrom, flash. Allow about 10 minutes. The stock
firmware isn't signed and nothing here burns efuses, so with the backup you can always go back.

## Before you start

On a Linux PC, install:
- `adb` and `fastboot` (Android platform tools);
- [`rkdeveloptool`](https://github.com/rockchip-linux/rkdeveloptool).

Your user needs access to the USB devices (the udev rules these packages ship), or run the tools with `sudo`.

On Windows, you need `adb` for the backup and Rockchip's RKDevTool to flash: see
[Windows: RKDevTool](#windows-rkdevtool).

Get the images: `d200-<version>-release.zip` from the
[latest release](https://github.com/riptidewave93/d200-buildroot/releases/latest), unpacked. Take the `release`
flavour unless you want SSH and a root shell on the D200 (`debug`, see [flavours](../README.md#building)). Your own
build works too: `make build`, then `output/<date>-<flavour>/`. The other docs call either folder the *image folder*.

## 1. Back up the stock firmware

**Do this first.** The backup is the only way back to the stock firmware, and it only fits your unit (it holds its
serial number and settings).

Plug the D200 in and let it boot. The stock firmware gives you root `adb` over USB-C:
```bash
adb devices                                  # the D200 should be listed
adb pull /dev/rkflash0 d200-factory.img      # 241172480 bytes
sha256sum d200-factory.img > d200-factory.img.sha256
```
On Windows, `certutil -hashfile d200-factory.img SHA256` shows the checksum; save it next to the image.
Keep both files somewhere safe. To restore them, see [recovery.md](recovery.md#4-restore-the-stock-firmware).

**No `adb`?** Back up from maskrom (step 2) with a patched Rockchip loader. It's Rockchip's binary, so it isn't
shipped here: build it yourself with [read-unlock/](read-unlock/README.md). Don't back up with
`rk3308_loader_wo_ftl.bin` or any other stock loader: past 32 MiB they return filler without an error.

## 2. Enter maskrom

Pick one:
- **adb:** `adb reboot loader`, then `rkdeveloptool rd 3`. Doesn't always work.
- **UART:** connect a 3.3 V UART ([recovery.md](recovery.md#2-with-a-uart)), then hold Ctrl-B while plugging in
  USB-C. The stock U-Boot enters maskrom.
- **Short:** short R9602 (the pad nearest the SoC) to GND while plugging in USB-C
  ([recovery.md](recovery.md#3-hardware-short-last-resort)).

Check: `rkdeveloptool ld` shows a `Maskrom` device (RKDevTool: "Found One MASKROM Device").

## 3. Flash

This replaces all stock data. From the image folder:
1. Start U-Boot from RAM while holding the **top-left key**, until the screen shows a USB plug and "Fastboot":
   ```bash
   rkdeveloptool db d200-usb-loader.bin
   ```
2. Flash. The D200 then reboots into the new firmware:
   ```bash
   ./flash-fastboot.sh
   ```

**Without `fastboot`:** download the `-maskrom.tar.xz` instead of the `.zip`, unpack it, and from its folder:
```bash
rkdeveloptool db rk3308_loader_wo_ftl.bin    # Rockchip's raw NAND loader
rkdeveloptool ef                             # erase everything first
rkdeveloptool wl 0 d200-full.img
rkdeveloptool rd
```
Prefer fastboot: it skips bad NAND blocks, and this way may not.

### Windows: RKDevTool

This erases everything on the D200 and installs the release flavour. You need:
- `d200-<version>-release-rkdevtool.zip` from the
  [latest release](https://github.com/riptidewave93/d200-buildroot/releases/latest), unpacked;
- Rockchip's driver,
  [DriverAssitant v5.14](https://github.com/industrialtablet/RockChip-Development-Tools/blob/main/RockChip%20Development%20Tools/DriverAssitant_v5.14.zip),
  and flashing tool,
  [RKDevTool v3.37](https://github.com/industrialtablet/RockChip-Development-Tools/blob/main/RockChip%20Development%20Tools/RKDevTool_v3.37_for_window.zip),
  unpacked.

1. Install the driver: `DriverInstall.exe` in the DriverAssitant folder, **Install Driver**.
2. RKDevTool starts in Chinese. For English, set `Selected=2` under `[Language]` in its `config.ini`.
3. With the D200 in maskrom (step 2), start `RKDevTool.exe`. It must show "Found One MASKROM Device", not "LOADER".
4. **Advanced Function** tab: pick `rk3308_loader_wo_ftl.bin` next to **Boot**, press **Download** and wait for
   "Found One LOADER Device".
5. Press **EraseAll** and wait for it to finish.
6. **Upgrade Firmware** tab: **Firmware**, pick `update.img`, then **Upgrade**. When the log shows "Download Firmware
   Success", the D200 restarts into the new firmware.

If the D200 doesn't start afterwards, use fastboot: [recovery.md](recovery.md).

## Next steps

1. Set up your keys on the [configuration website](https://riptidewave93.github.io/d200-configure/).
2. For PC actions (open URLs, launch apps, Discord, OBS, media players), install
   [deckhost](https://github.com/riptidewave93/d200-deck/blob/main/docs/install.md).
3. To update later, see [update.md](update.md).

The read-only USB drive the D200 shows on your PC lists its name and addresses.
