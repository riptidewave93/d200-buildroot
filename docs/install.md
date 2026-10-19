# Installing

Replacing the stock firmware takes three steps: back it up, enter maskrom, flash. Allow about 10 minutes. The stock
firmware isn't signed and nothing here burns efuses, so with the backup you can always go back.

You need, on a Linux PC:
- `adb`, and `fastboot` unless you flash with `rkdeveloptool` only (Android platform tools);
- [`rkdeveloptool`](https://github.com/rockchip-linux/rkdeveloptool);
- the images from a build: `make build` in this repo, then use `output/<date>-<flavour>/`.

Your user needs access to the USB devices (udev rules from the platform tools / rkdeveloptool packages), or run the
tools with `sudo`.

## 1. Back up the stock firmware

**Do this first.** The backup is the only way back to the stock firmware, and it is specific to your unit (it holds
its serial number and settings).

The stock firmware runs `adb` as root over USB-C. Plug the D200 in, let it boot, then:
```bash
adb devices                                  # the D200 should be listed
adb pull /dev/rkflash0 d200-factory.img
ls -l d200-factory.img                       # 241172480 bytes
sha256sum d200-factory.img > d200-factory.img.sha256
```
Keep both files somewhere safe. To restore them, see [recovery.md](recovery.md#4-restore-the-stock-firmware).

No adb? Enter maskrom (step 2) and read the flash with the patched loader in [read-unlock/](read-unlock/README.md).
Stock Rockchip loaders silently return garbage past 32 MiB.

## 2. Enter maskrom

Pick one:
- **adb:** `adb reboot loader`, then `rkdeveloptool reboot-maskrom`. Doesn't always work.
- **UART:** connect a 3.3 V UART ([hardware.md](hardware.md)), then hold Ctrl-B while plugging in USB-C. The stock
  U-Boot enters maskrom.
- **Short:** hold R9602 to GND while plugging in USB-C ([recovery.md](recovery.md#3-hardware-short-last-resort)).

Check: `rkdeveloptool list` shows a `Maskrom` device.

## 3. Flash

Either way replaces all stock data.

**rkdeveloptool only** (one image, nothing else needed):
```bash
cd output/<date>-<flavour>
rkdeveloptool db rk3308_loader_wo_ftl.bin    # Rockchip's raw NAND loader
rkdeveloptool ef                             # erase everything first: leftovers confuse UBI
rkdeveloptool wl 0 d200-full.img
rkdeveloptool rd
```

**Fastboot** (skips bad blocks, so it is the safer choice on a NAND that has some): run U-Boot from RAM while
holding the **top-left key**, so it enters fastboot (the screen shows a USB plug and "Fastboot"), then flash:
```bash
cd output/<date>-<flavour>
rkdeveloptool boot d200-usb-loader.bin       # hold the top-left key
./flash-fastboot.sh
```
The board then reboots into Linux. With a debug build you get `ssh root@d200-<serial>.local` over the USB cable (no
password; `<serial>` is the D200's USB serial number, e.g. from `lsusb -v -d 1d6b:0104`) and a root shell on the UART;
release builds have neither. For later updates, see [flashing.md](flashing.md).
