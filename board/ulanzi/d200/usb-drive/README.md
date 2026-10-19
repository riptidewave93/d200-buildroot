# Ulanzi D200

This D200 runs open-source firmware: mainline Linux and the d200-deck key app.
This drive is read-only.

| | |
|---|---|
| Firmware | @VERSION@ (@FLAVOR@ build) |
| Configure your keys | https://riptidewave93.github.io/d200-configure/ (coming soon) |
| OS / firmware image | https://github.com/riptidewave93/d200-buildroot |
| Key app (d200-deck) | https://github.com/riptidewave93/d200-deck |

## Debug build

The D200 is also a USB network adapter: it gives this computer the address
`172.31.254.2` and is itself at `172.31.254.1`.

| What | How |
|---|---|
| Shell | `ssh root@172.31.254.1` (no password) |
| Files | `scp` / `sftp` to `root@172.31.254.1` |
