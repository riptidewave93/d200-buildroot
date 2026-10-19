# Updating a D200

Three ways to update, easiest first. Settings are kept, except where noted.

| Way | Use it when |
|---|---|
| [1. Update page](#1-update-page) | The D200 runs normally. No extra tools needed |
| [2. Fastboot](#2-fastboot) | You have a build folder and `fastboot`, or the update page doesn't work |
| [3. Maskrom](#3-maskrom) | The D200 doesn't start, or doesn't get as far as fastboot |

Coming from the stock firmware? See [install.md](install.md) instead.

## 1. Update page

You need the update file, `d200-<version>-<flavour>-update.tar`, from a release or from a build's
`output/<date>-<flavour>/` folder.

> [!WARNING]
> **Do <ins>not</ins> unplug the D200 or let your PC shut down or sleep until the update page says the update is
> done.** The D200 is powered by your PC.

1. Open the D200's update page:
   - the **Update** item in the deckhost tray menu, or
   - `http://d200-<serial>.local/update`, or `http://<D200's IPv4 address>/update`.
2. Upload the update file. The D200 checks it before anything is written.
3. The D200 asks for confirmation on its screen. Press **Install** on the wide key (bottom-right), or **Cancel**
   (bottom-left). Nothing happens if no key is pressed within 2 minutes.
4. **Keep it plugged in and your PC on** while it writes. It then reboots once, into the new version, and the page
   shows the result.

The D200 keeps the version it was running. If the new one doesn't start properly, the D200 goes back to the
previous version by itself, and the page reports that the update was rolled back.

- A release D200 refuses a debug update file.
- An older version can be installed; the page warns first.
- If the D200 loses power while writing anyway, it starts the version it had. If it doesn't start at all, see
  [3. Maskrom](#3-maskrom).

## 2. Fastboot

You need `fastboot` (Android platform tools) and a build's `output/<date>-<flavour>/` folder.

1. Put the D200 in fastboot: hold the **top-left key** while plugging it in, until the screen shows a USB plug and
   "Fastboot". On a debug build, `reboot-to fastboot` over SSH does the same.
2. From the build folder:
   ```bash
   ./flash-fastboot.sh --uboot --no-reboot    # the bootloader
   ./flash-fastboot.sh --linux                # the system; then the D200 reboots
   ```

`--linux` writes the system into slot A and makes the D200 start from it. `./flash-fastboot.sh` with no options is a
full reinstall instead: it also **resets the settings**. All options are in [flashing.md](flashing.md#flashing).

## 3. Maskrom

You need `rkdeveloptool` and `fastboot`, and a build's `output/<date>-<flavour>/` folder.

1. Hold the **top-left and bottom-left keys** while plugging the D200 in. The screen stays dark;
   `rkdeveloptool list` shows a "Maskrom" device.
2. Start the bootloader from the PC, holding the **top-left key** so it goes into fastboot:
   ```bash
   rkdeveloptool boot d200-usb-loader.bin
   ```
3. Continue with [2. Fastboot](#2-fastboot), step 2. If the D200 was broken, use `./flash-fastboot.sh` with no
   options: a full reinstall, which **resets the settings**.

If the keys don't reach maskrom, see [recovery.md](recovery.md).
