# d200-buildroot

Open-source replacement firmware for the **Ulanzi D200** stream controller.

## What you get

- **14 keys with pages of buttons:** media keys, key combos, macros, icons and animated GIFs.
- **Setup in the browser:** the [configuration website](https://riptidewave93.github.io/d200-configure/) edits
  your keys over USB. Nothing to install.
- **PC actions** with [deckhost](https://github.com/riptidewave93/d200-deck/blob/main/docs/deckhost.md), the PC
  helper for Linux and Windows: open URLs, launch apps, control OBS, Discord and media players.
- **Updates from a web page** on the D200, confirmed on its keys. If an update doesn't start properly, the D200 goes
  back to the previous version by itself.
- **Recovery keys:** hold a key at power-on to reflash it over USB, without opening it.
- The screen dims while the PC sleeps.

## Get it

- [Install](docs/install.md): back up the stock firmware, then flash. About 10 minutes, and you can always go back.
- [Update](docs/update.md): a new version on a D200 that already runs this firmware.
- [Recovery](docs/recovery.md): a D200 that doesn't start, or going back to the stock firmware.

## The D200 project

| Repo | What |
|---|---|
| [d200-buildroot](https://github.com/riptidewave93/d200-buildroot) | The firmware: installing, updating, recovery |
| [d200-deck](https://github.com/riptidewave93/d200-deck) | The keys on the D200, and the PC helper |
| [d200-configure](https://github.com/riptidewave93/d200-configure) | The configuration website: https://riptidewave93.github.io/d200-configure/ |

## Building

You need Docker, `make` and `git`. The build runs in a Debian container as your user:
```bash
make build                # release image
make build FLAVOR=debug   # debug image
```
Images land in `output/<date>-<flavour>/`.

| Flavour | Differences |
|---|---|
| `release` (default) | No SSH, no shell, no U-Boot prompt |
| `debug` | Root shell on the UART and SSH over USB Ethernet (root, no password), the U-Boot console, debug tools |

More for developers (make targets, versions, the repo layout, how each part works): [docs/README.md](docs/README.md).

## License

GPL-2.0-or-later, like Buildroot; see [LICENSE](LICENSE). The Linux and U-Boot patches are under the licenses of the
files they change. The rkbin blobs (downloaded at build time) are Rockchip's and proprietary.
