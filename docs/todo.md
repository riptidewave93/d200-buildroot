# To do

## Next

| Item | Where |
|---|---|
| Test waking the PC with a key (kernel patch 0014, deckd writing `srp` when a key report times out), on Linux and Windows. On hold: with wakeup enabled on the test PC's root hub (`usb1`, shared with Bluetooth, a mic and a fan controller), the PC won't sleep (`hcd_pci_suspend returns -16`). Next: disable wakeup on the D200 only to see whether it or another device blocks it, or try a port on another controller | both |

## Later

| Item | Notes |
|---|---|
| Own USB VID:PID | e.g. pid.codes; `1d6b:0104` is the kernel's shared test ID |
| Hung deckd | A heartbeat, so a hung deckd is restarted and not only a crashed one |
| Windows | USB Ethernet binding, keys and the config channel |
| Fastboot entry glitch | Seen once: after `reboot-to fastboot` the D200 enumerated at full speed and failed (`-71`) until replugged. Watch for it |
| Signed updates | `manifest.sig` in bundle format 2; key handling and where the public key lives |
| `d200-full.img` and the new IDB layout | Untested: `rkdeveloptool wl` writes the IDB header page with ECC (the BootROM ignores ECC, so it should boot) |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
