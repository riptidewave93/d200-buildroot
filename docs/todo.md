# To do

## Next

| Item | Notes |
|---|---|
| Test waking the PC with a key (kernel patch 0014; deckd writes `srp` when a key report times out), on Linux and Windows | With wakeup enabled on the D200's root hub, one test PC refused to sleep (`hcd_pci_suspend returns -16`). Try a port on another USB controller, or find the device on that hub that blocks it |

## Later

| Item | Notes |
|---|---|
| Own USB VID:PID (optional) | `1d6b:0104` is the Linux Foundation's shared composite-gadget ID; tools also match the "Ulanzi D200" strings and the config channel's usage page. pid.codes takes software-only projects "with further justification" (open firmware for a commercial device). Changing IDs later means accepting both |
| Fastboot entry glitch | Seen once: after `reboot-to fastboot` the D200 enumerated at full speed and failed (`-71`) until replugged. Watch for it |
| First tagged release | The release job only runs on a `v*` tag and hasn't run yet; check its draft |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
