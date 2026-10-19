# To do

## Next

| Item | Where |
|---|---|
| `deck-update`: receive, check and write update bundles, confirm or report the result ([ota.md](ota.md)) | d200-deck |
| Test the maskrom keys after the SPL change (checked first thing in SPL now) | d200-buildroot |
| `hello` reports the OS version and flavour (`/etc/os-release`), not only deckd's version | d200-deck |
| Test the PC sleep fix (kernel patch 0013): sleep and wake the PC; the D200 must not be reset, and its log must not show `dwc2_hsotg_send_reply: cannot queue req` | d200-buildroot |

## Later

| Item | Notes |
|---|---|
| Wake the PC from sleep | dwc2 has no gadget remote wakeup (`.wakeup` op): patch it, set `bmAttributes` to `0xa0`, and have deckd trigger a wakeup (UDC `srp`) when a key is pressed while the bus is suspended. The PC must allow the device to wake it |
| USB Ethernet address override | A device setting to replace the per-device `198.18.0.0/15` `/30`, for PCs where it clashes |
| Linux udev rule | `uaccess` for the config channel's hidraw node, so the website works without root |
| Own USB VID:PID | e.g. pid.codes; `1d6b:0104` is the kernel's shared test ID |
| Hung deckd | A heartbeat, so a hung deckd is restarted and not only a crashed one |
| Windows | USB Ethernet binding, keys and the config channel |
| Fastboot entry glitch | Seen once: after `reboot-to fastboot` the D200 enumerated at full speed and failed (`-71`) until replugged. Watch for it |
| Signed updates | `manifest.sig` in bundle format 2; key handling and where the public key lives |
| `d200-full.img` and the new IDB layout | Untested: `rkdeveloptool wl` writes the IDB header page with ECC (the BootROM ignores ECC, so it should boot) |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
