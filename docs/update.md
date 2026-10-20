# Updating a D200

Two ways to update, easiest first. Settings are kept, except where noted.

| Way | Use it when |
|---|---|
| [1. Update page](#1-update-page) | The D200 runs normally. No extra tools needed |
| [2. Fastboot](#2-fastboot) | The update page doesn't work, or you switch between release and debug |
| [Recovery](recovery.md) | The D200 doesn't start |

Coming from the stock firmware? See [install.md](install.md) instead.

## 1. Update page

You need the update file, `d200-<version>-<flavour>-update.tar`, from the
[latest release](https://github.com/riptidewave93/d200-buildroot/releases/latest) or a build's `output/` folder.

> [!WARNING]
> **Do <ins>not</ins> unplug the D200 or let your PC shut down or sleep until the update page says the update is
> done.** The D200 is powered by your PC.

1. Open the D200's update page:
   - the **Update** item in the [deckhost](https://github.com/riptidewave93/d200-deck/blob/main/docs/deckhost.md)
     tray menu, or
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
  [recovery.md](recovery.md).

## 2. Fastboot

You need `fastboot` (Android platform tools) and the [image folder](install.md#before-you-start).

1. Put the D200 in fastboot: hold the **top-left key** while plugging it in, until the screen shows a USB plug and
   "Fastboot". On a debug build, `reboot-to fastboot` over SSH does the same.
2. From the image folder:
   ```bash
   ./flash-fastboot.sh --uboot --no-reboot    # the bootloader
   ./flash-fastboot.sh --linux                # the system; then the D200 reboots
   ```

`--linux` writes the system into slot A and makes the D200 start from it. `./flash-fastboot.sh` with no options is a
full reinstall instead: it also **resets the settings**. All options are in [flashing.md](flashing.md#flashing).
