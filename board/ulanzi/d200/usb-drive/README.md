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

The D200 is also a USB network adapter. It is `d200-<serial>.local`, where
`<serial>` is its USB serial number (lowercase), and its IPv4 address is the
one just below the address it gave this computer.

| What | How |
|---|---|
| Shell | `ssh root@d200-<serial>.local` (no password) |
| Files | `scp` / `sftp` to `root@d200-<serial>.local` |
