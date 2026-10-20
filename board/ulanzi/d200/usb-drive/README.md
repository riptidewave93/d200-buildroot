# Ulanzi D200

This D200 runs open-source firmware.
Firmware @VERSION@ (@FLAVOR@ build). This drive is read-only.

## Get started

- Install the PC app, deckhost (Windows/Linux):
  https://github.com/riptidewave93/d200-deck/blob/main/docs/install.md
- Configure your keys:
  https://riptidewave93.github.io/d200-configure/
- Update the firmware:
  https://github.com/riptidewave93/d200-buildroot/blob/main/docs/update.md
- Source code:
  https://github.com/riptidewave93/d200-buildroot (firmware)
  https://github.com/riptidewave93/d200-deck (key app, deckhost)

## This D200

Your D200 has these pages:

- Update: http://@IPV4@/update
- Debug info (for bug reports): http://@IPV4@/debug

If they don't open, try the D200's name or its IPv6 address instead:

  http://@NAME@/update
  http://[@IPV6@]/update

## Debug build

- Shell: ssh root@@IPV4@ (no password)
- Files: scp or sftp to root@@IPV4@
- Fastboot: reboot-to fastboot (in the shell)
