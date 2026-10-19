# To do

## Next

| Item | Where |
|---|---|
| `hello` reports the OS version and flavour (`/etc/os-release`), not only deckd's version | d200-deck |
| Test the PC sleep fix (kernel patch 0013, dwc2 stayed suspended after the bus resumed): sleep and wake the PC; the D200 must not be reset and the log must not show `dwc2_hsotg_send_reply: cannot queue req` | d200-buildroot |

## Later

| Item | Notes |
|---|---|
| Wake the PC from sleep | dwc2 has no gadget remote wakeup (`.wakeup` op): patch it, set `bmAttributes` to `0xa0`, and have deckd trigger a wakeup (UDC `srp`) when a key is pressed while the bus is suspended. The PC must allow the device to wake it |
| Updates without fastboot (OTA) | A/B kernel and rootfs volumes, a `/data` volume for the config, U-Boot boot counter with a `slot` variable, numeric `VERSION_ID` and git tags. Changes the UBI layout, so it needs a full reinstall. Look at U-Boot's own A/B support first (`boot/android_ab.c`, `ab_select`, bootmeths); it keeps its state in a block-device partition, so check how that fits UBI. Updates come in through `deck-update` (d200-deck) over USB Ethernet |
| OTA requirements (agreed so far) | Writes only the inactive slot; a failed upload or write is reported and that slot wiped. U-Boot must be updatable too: write and verify `u-boot-backup`, then `u-boot`, and test that SPL really falls back to the backup when the primary fails its FIT check. `idbloader` (TPL/SPL) stays fastboot/maskrom-only for now, see below. The update file is signed (kernel + rootfs + U-Boot + manifest), not `d200-full.img`. Open: read-only rootfs + `/data` volume vs copying the active slot at boot |
| `idbloader` over OTA? | The BootROM checks only the IDB header, not the data, and pages in a NAND block are programmed in order (header first). A power cut while rewriting a copy can leave a valid header over half-written data, which the BootROM would still try to run. Possible way out: test whether the BootROM moves on to the next copy when a copy's data is bad |
| USB Ethernet address override | A device setting to replace the per-device `198.18.0.0/15` `/30`, for PCs where it clashes |
| Linux udev rule | `uaccess` for the config channel's hidraw node, so the website works without root |
| Own USB VID:PID | e.g. pid.codes; `1d6b:0104` is the kernel's shared test ID |
| Hung deckd | A heartbeat, so a hung deckd is restarted and not only a crashed one |
| Windows | USB Ethernet binding, keys and the config channel |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
