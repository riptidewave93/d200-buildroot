# To do

| Item | Notes |
|---|---|
| PC sleep tests | Sleep detection works. Still to test on a PC that can sleep: waking the PC with a key, `deckd` starting while the PC sleeps, PC shutdown |
| Release workflow | Another dry run (it now also collects and checks the files), then the first real release; check the files and signed bundles it attaches |
| `d200-full.img` and bad blocks | Untested on a flash with bad blocks |
| Fastboot entry glitch | Seen once: after `reboot-to fastboot` the D200 enumerated at full speed and failed until replugged |
