# To do

## Next

| Item | Where |
|---|---|
| Test waking the PC with a key (kernel patch 0014, deckd writing `srp` when a key report times out), on Linux and Windows. On the PC tested so far, enabling wakeup on the root hub the D200 is on kept the PC from sleeping (`hcd_pci_suspend returns -16`); try a port on another USB controller, or find which device on that hub blocks it | both |

## Later

| Item | Notes |
|---|---|
| Own USB VID:PID (optional) | `1d6b:0104` is the Linux Foundation's shared composite-gadget ID; tools also match the "Ulanzi D200" strings and the config channel's usage page. pid.codes takes software-only projects "with further justification" (open firmware for a commercial device); worth asking before a public release, since changing IDs later means accepting both |
| Fastboot entry glitch | Seen once: after `reboot-to fastboot` the D200 enumerated at full speed and failed (`-71`) until replugged. Watch for it |
| Release workflow | `.github/workflows/release.yml` builds both flavours (about an hour), signs with the `D200_SIGNING_KEY` secret and drafts a release on a `v*` tag. The builds pass; the release job first runs on a tag |
| `d200-full.img` and bad blocks | How rkbin's raw NAND loader handles bad blocks is untested (the test board has none) |
