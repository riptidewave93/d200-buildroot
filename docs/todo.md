# To do

## Next

| Item | Where |
|---|---|
| Test a release build on the board: no SSH or UART shell, no U-Boot prompt, falls back to fastboot when Linux doesn't boot | here |
| `hello` reports the OS version and flavour (`/etc/os-release`), not only deckd's version | d200-deck |
| USB drive model name: drop "Stream Deck" (Elgato's trademark), e.g. "D200 Deck" | `S30usb-gadget` |
| Regenerate the Linux 0012 and U-Boot 0014 device tree patches with `git format-patch`; they were edited in place | `board/ulanzi/d200/patches/` |
| Make `idbloader`, `u-boot` and `u-boot-backup` read-only in Linux (U-Boot keeps them writable for fastboot) | Linux DT patch |

## Later

| Item | Notes |
|---|---|
| Wake the PC from sleep | dwc2 has no gadget remote wakeup (`.wakeup` op): patch it, set `bmAttributes` to `0xa0`, and have deckd trigger a wakeup (UDC `srp`) when a key is pressed while the bus is suspended. The PC must allow the device to wake it |
| Updates without fastboot (OTA) | A/B kernel and rootfs volumes, a `/data` volume for the config, U-Boot boot counter with a `slot` variable, numeric `VERSION_ID` and git tags. Changes the UBI layout, so it needs a full reinstall |
| Linux udev rule | `uaccess` for the config channel's hidraw node, so the website works without root |
| Own USB VID:PID | e.g. pid.codes; `1d6b:0104` is the kernel's shared test ID |
| Hung deckd | A heartbeat, so a hung deckd is restarted and not only a crashed one |
| Windows | USB Ethernet binding, keys and the config channel |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
