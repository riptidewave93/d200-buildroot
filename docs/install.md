# Installing

Replacing the stock firmware takes three steps: back it up, enter maskrom, flash. Allow about 10 minutes. The stock
firmware isn't signed and nothing here burns efuses, so with the backup you can always go back.

## Before you start

On a Linux PC, install:
- `adb` and `fastboot` (Android platform tools);
- [`rkdeveloptool`](https://github.com/rockchip-linux/rkdeveloptool).

Your user needs access to the USB devices (the udev rules these packages ship), or run the tools with `sudo`.

Get the images: the `.zip` from a [release](https://github.com/riptidewave93/d200-buildroot/releases), unpacked.
Take the `release` flavour unless you want SSH and a root shell on the D200 (`debug`, see
[flavours](../README.md#building)). Your own build works too: `make build`, then `output/<date>-<flavour>/`. The
other docs call either folder the *image folder*.

## 1. Back up the stock firmware

**Do this first.** The backup is the only way back to the stock firmware, and it only fits your unit (it holds its
serial number and settings).

Plug the D200 in and let it boot. The stock firmware gives you root `adb` over USB-C:
```bash
adb devices                                  # the D200 should be listed
adb pull /dev/rkflash0 d200-factory.img      # 241172480 bytes
sha256sum d200-factory.img > d200-factory.img.sha256
```
Keep both files somewhere safe. To restore them, see [recovery.md](recovery.md#4-restore-the-stock-firmware).

**No `adb`?** Back up from maskrom (step 2) with a patched Rockchip loader. To prevent possible license issues, you
need to build it yourself: see [read-unlock/](read-unlock/README.md). Don't back up with `rk3308_loader_wo_ftl.bin`
or any other stock loader: past 32 MiB they return filler without an error.

## 2. Enter maskrom

Pick one:
- **adb:** `adb reboot loader`, then `rkdeveloptool rd 3`. Doesn't always work.
- **UART:** connect a 3.3 V UART ([recovery.md](recovery.md#2-with-a-uart)), then hold Ctrl-B while plugging in
  USB-C. The stock U-Boot enters maskrom.
- **Short:** short R9602 (the pad nearest the SoC) to GND while plugging in USB-C
  ([recovery.md](recovery.md#3-hardware-short-last-resort)).

Check: `rkdeveloptool ld` shows a `Maskrom` device.

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

## Next steps

1. Set up your keys on the [configuration website](https://riptidewave93.github.io/d200-configure/).
2. For PC actions (open URLs, launch apps, Discord, OBS, media players), install
   [deckhost](https://github.com/riptidewave93/d200-deck/blob/main/docs/install.md).
3. To update later, see [update.md](update.md).

The read-only USB drive the D200 shows on your PC lists its name and addresses.
