# Updates (A/B)

How the D200 updates itself: what the system provides, and what the updater (`deckd update`, in
[d200-deck](https://github.com/riptidewave93/d200-deck)) does with it. Flashing over fastboot is in
[flashing.md](flashing.md).

In short:
- Linux runs from one of two slots, A or B.
- An update writes the other slot (and the bootloader, when it changed), switches slots and reboots once.
- If the new slot doesn't come up healthy, U-Boot switches back by itself.
- The bootloader has no second slot. Its writes are safe against power cuts instead, and the recovery keys cover a
  bad U-Boot.

## Layout

The partitions and UBI volumes are listed in [flashing.md](flashing.md#nand-layout). For the updater:

| Target | Where |
|---|---|
| `idbloader` | MTD partition `idbloader`: 4 copies of one 256 KiB IDB copy, at fixed offsets |
| `u-boot` | MTD partitions `u-boot-backup` and `u-boot`, the same image in both |
| `kernel` | UBI volume `kernel_a` (id 2) or `kernel_b` (id 3), static, 8 MiB |
| `rootfs` | UBI volume `rootfs_a` (id 4) or `rootfs_b` (id 5), dynamic, 32 MiB |

The incoming bundle goes to `/data/update`, which is emptied at every boot. A fresh install has slot A only: the
first update creates `kernel_b` and `rootfs_b`.

## Boot

U-Boot boots `slot` and passes it on the kernel command line as `d200.slot=a|b`. If that slot doesn't boot (empty or
half-written volume, bad FIT hash), U-Boot boots the other slot in the same boot.

The env is stored in the UBI volumes `env` and `env_r` (redundant). U-Boot imports only these variables from it;
everything else comes from the running U-Boot's defaults:

| Variable | Values | Meaning |
|---|---|---|
| `slot` | `a`, `b` | Slot to boot |
| `upgrade_available` | `0`, `1` | `1`: the slot is on trial, and every boot counts |
| `bootcount` | number | Boots since the trial started. Past 3, U-Boot switches `slot` and sets `upgrade_available=0`, `bootcount=0`, `ota_result=rolled-back` |
| `ota_result` | `trial`, `ok`, `failed`, `rolled-back`, `fell-back` | Outcome of the last update, or `fell-back` when the stable slot stopped booting |
| `panel` | `h1`, `h3`, `auto` | Panel config; unset or `auto`: detect ([hardware.md](hardware.md#panels)) |

Linux reads and writes them with `fw_printenv` / `fw_setenv`. A fresh install has an empty env; the tools then use
`slot=a`.

## Bundle

An uncompressed ustar archive, `d200-<version>-<flavour>-update.tar`: `manifest.json`, then `manifest.sig` (signed
bundles only), then the images in write order.

```json
{
  "format": 1,
  "product": "d200",
  "flavour": "release",
  "version": "v0.1.0",
  "build_id": 202610191900,
  "min_updater": 1,
  "images": [
    {"target": "idbloader", "file": "idbloader.img", "size": 262144, "sha256": "…"},
    {"target": "u-boot", "file": "u-boot.itb", "size": 1216512, "sha256": "…"},
    {"target": "kernel", "file": "kernel.itb", "size": 3270068, "sha256": "…"},
    {"target": "rootfs", "file": "rootfs.ubifs", "size": 6729728, "sha256": "…"}
  ]
}
```

- `build_id` is `BUILD_ID` from `/usr/lib/os-release` (UTC `YYYYMMDDHHMM`), the number to compare for "newer".
- `min_updater` (default 1) is the oldest updater version that can install the bundle; `min_updater_release`
  (optional) names the release that has it. An image with `"optional": true` is skipped by an updater that doesn't
  know its target.
- Every bundle carries all four images; an image identical to what is on the flash isn't rewritten. U-Boot and
  kernel builds are reproducible, so they only change when their patches, config or rkbin change.
- `manifest.sig` is the Ed25519 signature of `manifest.json`, which covers the images through their hashes.

The bundle is built by `board/ulanzi/d200/post-image.sh`. When older devices must still install it:

| Change | Do |
|---|---|
| A new image older devices can go without | Mark it optional |
| Anything an older updater would get wrong (a new required image, a new write step, a changed field) | Raise `min_updater` to d200-deck's new `ota.UpdaterVersion`, and set `min_updater_release` |

## Signing

Official builds are signed; other builds aren't, and install all the same. The update page shows "Official build"
or "Unofficial build".

- The build signs when `D200_SIGNING_KEY` holds an Ed25519 private key (PEM), e.g.
  `D200_SIGNING_KEY="$(cat keys/update-key.pem)" make build`. Releases are signed in GitHub Actions from the
  repository secret `D200_SIGNING_KEY`. The private key is never in git: `keys/` and `*.pem` are ignored.
- The D200 checks it against `/etc/d200/update-key.pub`, from `rootfs-overlay/etc/d200/update-key.pub`. A fork that
  signs its own builds replaces it with its public key.

Make a key pair with `openssl genpkey -algorithm ed25519 -out key.pem` and
`openssl pkey -in key.pem -pubout -out update-key.pub`.

## Updating

What the updater does:
1. Streams the bundle into `/data/update` and checks it: `format` 1, `product` `d200`, `min_updater`, known or
   optional targets, every file's size and sha256. A release device refuses a debug bundle.
2. Waits for the confirming key press on the D200.
3. Writes `idbloader`, `u-boot-backup`, `u-boot`, then `kernel` and `rootfs` into the inactive slot (the one
   `d200.slot` doesn't name). Each write is read back, and retried once.
4. Activates the new slot with one env write, and reboots:
   `fw_setenv slot <inactive> upgrade_available 1 bootcount 0 ota_result trial`.
5. After the reboot, confirms the trial once the key app is healthy (`upgrade_available 0 bootcount 0 ota_result
   ok`), or records `failed` / `fell-back` when the D200 runs another slot than `slot`.

## Power cuts

| During | Result |
|---|---|
| Receiving the bundle | Nothing written; the partial files are removed at the next boot |
| An IDB copy | That copy is invalid until it's complete; another copy boots |
| `u-boot-backup` or `u-boot` | The other one is good; SPL boots it |
| A kernel or rootfs volume | The volume is marked incomplete; the active slot boots |
| An env write | The redundant env keeps the old or the new state |
| The trial boot | Counts as a failed boot (limit 3) |
