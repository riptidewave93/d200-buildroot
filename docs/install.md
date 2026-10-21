# Installing

Replacing the stock firmware takes two steps: enter maskrom (the chip's built-in USB flashing mode), then flash.
Allow about 10 minutes. Nothing here is permanent, so you can always [go back](recovery.md#4-back-to-stock).

## Before you start

Download from the [latest release](https://github.com/riptidewave93/d200-buildroot/releases/latest) and unpack:
- macOS and Linux: `d200-<version>-release-maskrom.tar.xz`;
- Windows: `d200-<version>-release-rkdevtool.zip`.

Take the `release` flavour unless you want SSH and a root shell on the D200 (`debug`, see
[flavours](../README.md#building); macOS and Linux only).

Install `adb` (Android platform tools), for step 1:

| OS | Command |
|---|---|
| macOS | `brew install android-platform-tools` (with [Homebrew](https://brew.sh)) |
| Debian, Ubuntu | `sudo apt install adb` |
| Fedora | `sudo dnf install android-tools` |
| Arch | `sudo pacman -S android-tools` |
| Windows | [SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools), unpacked; run `adb` from its folder |

Windows: also install Rockchip's [DriverAssitant v5.14](https://github.com/industrialtablet/RockChip-Development-Tools/raw/main/RockChip%20Development%20Tools/DriverAssitant_v5.14.zip): unpack it, run `DriverInstall.exe`, press
**Install Driver**.

## 1. Enter maskrom

With the D200 on the stock firmware and plugged in, check that `adb devices` lists it, then:
```bash
adb shell "sync; devmem 0xff000500 32 0xEF08A53C; devmem 0xff5000b8 32 0xfdb9"
```
This tells the chip to start in maskrom and resets it, so adb disconnects. Nothing is written to the flash: unplug it
without flashing and it starts the stock firmware again.

If adb doesn't work:
- **UART:** connect a 3.3 V UART ([recovery.md](recovery.md#2-with-a-uart)), then hold Ctrl-B while plugging in
  USB-C. The stock U-Boot enters maskrom.
- **Short:** short R9602 (the pad nearest the SoC) to GND while plugging in USB-C
  ([recovery.md](recovery.md#3-hardware-short-last-resort)).

## 2. Flash

This erases everything on the D200, then installs the new firmware.

### macOS and Linux

`d200-install.py` in the unpacked folder does the install. It needs Python 3 and a USB library, which it gets in a
folder of its own (`d200-venv`), so nothing else on your PC changes. If `python3` is missing: on macOS, running it
offers to install it (or `brew install python`); on Debian and Ubuntu, `sudo apt install python3-venv`.

macOS, in Terminal:
```bash
cd ~/Downloads/d200-v*-release-maskrom             # the unpacked folder
python3 -m venv d200-venv                          # make the installer's Python folder
d200-venv/bin/pip install pyusb libusb-package     # add the USB library to it
d200-venv/bin/python d200-install.py               # install
```

Linux:
```bash
cd ~/Downloads/d200-v*-release-maskrom             # the unpacked folder
python3 -m venv d200-venv                          # make the installer's Python folder
d200-venv/bin/pip install pyusb libusb-package     # add the USB library to it
sudo d200-venv/bin/python d200-install.py          # install (sudo for USB access)
```

It shows each step. When it's done, the D200 restarts into the new firmware.

### Windows: RKDevTool

You also need Rockchip's flashing tool, [RKDevTool v3.37](https://github.com/industrialtablet/RockChip-Development-Tools/raw/main/RockChip%20Development%20Tools/RKDevTool_v3.37_for_window.zip), unpacked.

1. RKDevTool starts in Chinese. For English, set `Selected=2` under `[Language]` in its `config.ini`.
2. With the D200 in maskrom ([1. Enter maskrom](#1-enter-maskrom)), start `RKDevTool.exe`. It must show "Found One
   MASKROM Device", not "LOADER".
3. **Advanced Function** tab: pick `rk3308_loader_wo_ftl.bin` next to **Boot**, press **Download** and wait for
   "Found One LOADER Device".
4. Press **EraseAll** and wait for it to finish.
5. **Upgrade Firmware** tab: **Firmware**, pick `update.img` from the unpacked zip, then **Upgrade**. When the log
   shows "Download Firmware Success", the D200 restarts into the new firmware.

Either way: if the D200 doesn't start afterwards, see [Recovery](recovery.md#12-maskrom-keys).

## Next steps

1. Set up your keys on the [configuration website](https://riptidewave93.github.io/d200-configure/).
2. For PC actions (open URLs, launch apps, Discord, OBS, media players), install
   [deckhost](https://github.com/riptidewave93/d200-deck/blob/main/docs/install.md).
3. To update later, see [update.md](update.md).

The D200 also shows up on your PC as a small read-only USB drive, with these links and its web address.
