# To do

## Next

| Item | Where |
|---|---|
| `hello` reports the OS version and flavour (`/etc/os-release`), not only deckd's version | d200-deck |
| Test the PC sleep fix (kernel patch 0013): sleep and wake the PC; the D200 must not be reset, and its log must not show `dwc2_hsotg_send_reply: cannot queue req` | d200-buildroot |

## Later

| Item | Notes |
|---|---|
| Wake the PC from sleep | dwc2 has no gadget remote wakeup (`.wakeup` op): patch it, set `bmAttributes` to `0xa0`, and have deckd trigger a wakeup (UDC `srp`) when a key is pressed while the bus is suspended. The PC must allow the device to wake it |
| Updates without fastboot (OTA) | A/B kernel and rootfs volumes, a `/data` volume for the config, U-Boot boot counter with a `slot` variable, numeric `VERSION_ID` and git tags. Changes the UBI layout, so it needs a full reinstall. Look at U-Boot's own A/B support first (`boot/android_ab.c`, `ab_select`, bootmeths); it keeps its state in a block-device partition, so check how that fits UBI. Updates come in through `deck-update` (d200-deck) over USB Ethernet |
| OTA requirements (agreed so far) | One reboot per update. Writes only the inactive OS slot; the bundle is received into `/data/update` (on flash; RAM is tight), extracted as it streams, and fully verified before the first write; `/data/update` is emptied at every boot; a failed write is retried once, then the update stops, is reported and that slot wiped (a new bootloader stays; a bootloader copy that fails twice is left invalid as long as 2 good copies remain); the OS rolls back by itself (bootcount). Every bundle that changes the U-Boot version also carries SPL; TPL only when rkbin is bumped. Bootloader writes go riskiest first: TPL/SPL, `u-boot-backup`, `u-boot`. A broken TPL/SPL build is caught by bench testing before release (on both boards); everything after SPL is covered by the recovery keys. The update file is signed (kernel + rootfs + U-Boot + manifest), not `d200-full.img` |
| `idbloader` over OTA | Power-cut safe with a new layout (tested). The BootROM checks only the IDB header (V1 has no hash), ignores ECC errors, and honours the header's `init_offset` relative to each copy. So the code goes in the copy's second NAND block (offset 256), and a copy is updated by erasing its header block, writing and verifying the code block, then writing the header page raw in two passes, magic last (a header without its magic is skipped; tested). To do: this layout in `post-image.sh`/`flash-fastboot.sh` (written without bad-block skipping, so copies never shift; IDB blocks are never marked bad), and the recovery-key check moved to the very start of SPL |
| USB Ethernet address override | A device setting to replace the per-device `198.18.0.0/15` `/30`, for PCs where it clashes |
| Linux udev rule | `uaccess` for the config channel's hidraw node, so the website works without root |
| Own USB VID:PID | e.g. pid.codes; `1d6b:0104` is the kernel's shared test ID |
| Hung deckd | A heartbeat, so a hung deckd is restarted and not only a crashed one |
| Windows | USB Ethernet binding, keys and the config channel |
| Fastboot entry glitch | Seen once: after `reboot-to fastboot` the D200 enumerated at full speed and failed (`-71`) until replugged. Watch for it |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
