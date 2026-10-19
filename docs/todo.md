# To do

## Next

| Item | Where |
|---|---|
| Test the PC sleep fix (kernel patch 0013): sleep and wake the PC; the D200 must not be reset, and its log must not show `dwc2_hsotg_send_reply: cannot queue req` | d200-buildroot |
| Test waking the PC with a key (kernel patch 0014, deckd writing `srp` on `EAGAIN`), on Linux and Windows | both |

## Later

| Item | Notes |
|---|---|
| USB Ethernet address override | A device setting to replace the per-device `198.18.0.0/15` `/30`, for PCs where it clashes |
| Own USB VID:PID | e.g. pid.codes; `1d6b:0104` is the kernel's shared test ID |
| Hung deckd | A heartbeat, so a hung deckd is restarted and not only a crashed one |
| Windows | USB Ethernet binding, keys and the config channel |
| Fastboot entry glitch | Seen once: after `reboot-to fastboot` the D200 enumerated at full speed and failed (`-71`) until replugged. Watch for it |
| Signed updates | `manifest.sig` in bundle format 2; key handling and where the public key lives |
| `d200-full.img` and the new IDB layout | Untested: `rkdeveloptool wl` writes the IDB header page with ECC (the BootROM ignores ECC, so it should boot) |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
