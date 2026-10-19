# To do

## Next

| Item | Where |
|---|---|
| `hello` reports the OS version and flavour (`/etc/os-release`), not only deckd's version | d200-deck |
| Key combo on the deck to reboot into fastboot (e.g. hold top-left + bottom-left for 5 s), so a release build can be reflashed without replugging | d200-deck |

## Later

| Item | Notes |
|---|---|
| Clean resume after PC sleep | When the PC resumes it sends GET_STATUS; dwc2 fails to reply (`dwc2_hsotg_send_reply: cannot queue req`, ep0 still busy) and the PC resets the D200. The deck recovers, but the config channel drops |
| Wake the PC from sleep | dwc2 has no gadget remote wakeup (`.wakeup` op): patch it, set `bmAttributes` to `0xa0`, and have deckd trigger a wakeup (UDC `srp`) when a key is pressed while the bus is suspended. The PC must allow the device to wake it |
| Updates without fastboot (OTA) | A/B kernel and rootfs volumes, a `/data` volume for the config, U-Boot boot counter with a `slot` variable, numeric `VERSION_ID` and git tags. Changes the UBI layout, so it needs a full reinstall. Look at U-Boot's own A/B support first (`boot/android_ab.c`, `ab_select`, bootmeths); it keeps its state in a block-device partition, so check how that fits UBI. Updates come in through `deck-update` (d200-deck) over USB Ethernet |
| OTA requirements (agreed so far) | Writes only the inactive slot; a failed upload or write is reported and that slot wiped. U-Boot must be updatable too: write and verify `u-boot-backup`, then `u-boot`, and test that SPL really falls back to the backup when the primary fails its FIT check. `idbloader` (TPL/SPL) stays fastboot/maskrom-only for now, see below. The update file is signed (kernel + rootfs + U-Boot + manifest), not `d200-full.img`. Open: read-only rootfs + `/data` volume vs copying the active slot at boot |
| `idbloader` over OTA? | The BootROM checks only the IDB header, not the data, and pages in a NAND block are programmed in order (header first). A power cut while rewriting a copy can leave a valid header over half-written data, which the BootROM would still try to run. Possible way out: test whether the BootROM moves on to the next copy when a copy's data is bad |
| Several D200s on one PC | Today every deck uses `172.31.254.0/30`, which clashes between decks (and Docker allocates from `172.16.0.0/12`). Proposal: dual-stack, derived from the CPU serial. IPv4: a per-deck `/30` in `198.18.0.0/15` (32768 links; longest-prefix match means a clash only shadows the deck's own 4 addresses), with a device setting to override the range. IPv6: a ULA `/64` (`fd` + 40 bits from the serial) by router advertisement, no default route. mDNS name `d200-<serial>.local`; deckhost and the website can also compute the address from the serial in `hello`. Needs IPv6 in the kernel (~300 KB), an RA sender and an mDNS responder (small, in Go) |
| Linux udev rule | `uaccess` for the config channel's hidraw node, so the website works without root |
| Own USB VID:PID | e.g. pid.codes; `1d6b:0104` is the kernel's shared test ID |
| Hung deckd | A heartbeat, so a hung deckd is restarted and not only a crashed one |
| Windows | USB Ethernet binding, keys and the config channel |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
