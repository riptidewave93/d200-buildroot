# Updates (A/B)

How the D200 updates itself over USB: what the system provides, and what the updater (`deckd update`, in
[d200-deck](https://github.com/riptidewave93/d200-deck)) does with it. Flashing over fastboot is in
[flashing.md](flashing.md).

In short:
- Linux runs from one of two slots, A or B.
- An update writes the other slot (and, when the bundle has them, the bootloader), switches slots and reboots
  once.
- If the new slot doesn't come up healthy, U-Boot switches back by itself.
- The bootloader has no second slot. Its writes are made safe against power cuts instead, and the recovery keys
  cover a bad U-Boot.

## Layout

The flash partitions and UBI volumes are listed in [flashing.md](flashing.md#nand-layout). For the updater:

| Target | Device | Notes |
|---|---|---|
| `idbloader` | MTD partition `idbloader` (`/proc/mtd`), 1 MiB | 4 copies of one 256 KiB IDB copy, at fixed offsets |
| `u-boot` | MTD partitions `u-boot-backup` and `u-boot`, 4 MiB each | Same image in both; SPL skips bad blocks |
| `kernel` | UBI volume `kernel_a` (id 2) or `kernel_b` (id 3), static, 8 MiB | `/dev/ubi0_2`, `/dev/ubi0_3` |
| `rootfs` | UBI volume `rootfs_a` (id 4) or `rootfs_b` (id 5), dynamic, 32 MiB | Mounted read-only |
| — | UBI volume `data` (id 6), 100 MiB | `/data`, always mounted; `/data/update` for the incoming bundle |

The volume IDs are fixed (splash is 7). A fresh install has slot A only: the first update creates `kernel_b`
and `rootfs_b`.

## Boot

U-Boot boots `slot` (`a` or `b`) and passes it on the kernel command line as `d200.slot=a|b`, with
`root=ubi0:rootfs_<slot> ro`. If that slot doesn't boot (empty or half-written volume, bad FIT hash), U-Boot
boots the other slot in the same boot.

The env lives in the UBI volumes `env` and `env_r` (redundant). The saved env can only set these variables;
everything else comes from the running U-Boot:

| Variable | Values | Meaning |
|---|---|---|
| `slot` | `a`, `b` | Slot to boot |
| `upgrade_available` | `0`, `1` | `1`: the slot is on trial. Every boot counts, and the env is saved each boot |
| `bootcount` | number | Boots since the trial started. Past 3, U-Boot switches `slot`, sets `upgrade_available=0`, `bootcount=0`, `ota_result=rolled-back` |
| `ota_result` | `trial`, `ok`, `failed`, `rolled-back`, `fell-back` | Outcome of the last update, or `fell-back` when the stable slot stopped booting, for the updater to report |

Linux reads and writes them with `fw_printenv` / `fw_setenv` (`/etc/fw_env.config`). A fresh install has an
empty env; the tools then use the defaults from `/etc/u-boot-initial-env` (`slot=a`).

## Bundle

An uncompressed ustar archive, `d200-<version>-<flavour>-update.tar`. Members, in order:

1. `manifest.json`
2. `manifest.sig`, only in signed bundles
3. the images, in write order: `idbloader.img`, `u-boot.itb`, `kernel.itb`, `rootfs.ubifs`

```json
{
  "format": 1,
  "product": "d200",
  "flavour": "release",
  "version": "1a2b3c4",
  "build_id": 202610191900,
  "images": [
    {"target": "idbloader", "file": "idbloader.img", "size": 262144, "sha256": "…"},
    {"target": "u-boot", "file": "u-boot.itb", "size": 1216512, "sha256": "…"},
    {"target": "kernel", "file": "kernel.itb", "size": 3270068, "sha256": "…"},
    {"target": "rootfs", "file": "rootfs.ubifs", "size": 6729728, "sha256": "…"}
  ]
}
```

- `build_id` is `BUILD_ID` from `/usr/lib/os-release` (UTC `YYYYMMDDHHMM`), the number to compare for "newer".
- `idbloader.img` is one 256 KiB IDB copy:
  - bytes `0x0`–`0x7ff` are the header page;
  - bytes `0x20000`–`0x3ffff` are the code block (TPL + SPL);
  - everything else is `0xff`.
- Every bundle carries all four images. A bootloader image identical to what is on the flash is not rewritten.
  U-Boot and kernel builds are reproducible (each is dated by the last commit that changed it), so a build without
  U-Boot or kernel changes carries the same `idbloader.img`, `u-boot.itb` and `kernel.itb`.
- `manifest.sig` is the raw 64-byte Ed25519 signature of `manifest.json`'s exact bytes, which covers the images
  through their hashes. See [Signing](#signing).

## Signing

Official builds are signed; anyone else's build is not, and installs all the same. The signature only tells the
user whether a bundle is an official build.

- The build signs when `D200_SIGNING_KEY` holds an Ed25519 private key (PEM), e.g.
  `D200_SIGNING_KEY="$(cat keys/update-key.pem)" make build`. Official releases are signed in GitHub Actions from
  the repository secret `D200_SIGNING_KEY`. The private key is never in git: `keys/` and `*.pem` are ignored.
- The D200 checks it against `/etc/d200/update-key.pub` (PEM, from `rootfs-overlay/etc/d200/update-key.pub`). The
  update page says "Official build" if it verifies, "Unofficial build" otherwise (no signature, no key, another key).
- A fork that signs its own builds replaces `update-key.pub` with its public key.

Make a key pair with `openssl genpkey -algorithm ed25519 -out key.pem` and
`openssl pkey -in key.pem -pubout -out update-key.pub`.

## Updating

Everything below is done by the updater, as root.

**Receive:**
1. Check the free space on `/data` against the upload size, then stream the tar into `/data/update/`, one file
   per member, hashing each file as it is written.
2. Reject the bundle unless:
   - `format` is 1 and `product` is `d200`;
   - every listed file is present with the right size and sha256, and there are no other files besides
     `manifest.sig`.
3. A release device refuses `flavour: debug`.
4. Wait for the confirming key press on the device before writing anything.

`/data/update` is emptied at every boot (`S00data`). The updater empties it too when an update fails without a
reboot.

**Write**, in this order. Each target is retried once from its file before the update stops. A stop leaves
what was already written; every step is compatible with the running system.

1. **`idbloader`** (skip it if all 4 copies already match). For each copy at `k × 0x40000`, `k` = 3, 2, 1, 0:
   1. Erase the header block (`k × 0x40000`). The copy is now invalid; the BootROM uses another one.
   2. Erase the code block (`k × 0x40000 + 0x20000`), write the code block, and read it back.
   3. Write the header page in two raw passes (`MEMWRITE` with `MTD_OPS_RAW`, 2048 data bytes plus 128 OOB
      bytes, all OOB `0xff`):
      - first the header page with its first 4 bytes (the magic) set to `0xff`;
      - then a page of `0xff` with only those 4 bytes.
   4. Read the page back raw and compare.

   The BootROM ignores ECC and skips a header without its magic, so a power cut at any point leaves a copy that
   is either invalid or complete. Normal (ECC) reads of a header page report `EBADMSG` by design; always
   compare it raw.

   Never mark these blocks bad, and never skip one: the copies must stay at their offsets. A copy that fails
   twice is left with its header block erased. Carry on while at least 2 copies are good; with fewer, stop.
2. **`u-boot`** (skip it if both partitions already match):
   - Write `u-boot-backup`, then `u-boot`.
   - For each partition, erase and write the good blocks in order, skipping bad blocks (`MEMGETBADBLOCK`), then
     read back and compare.
   - On an erase or write error, mark the block bad (`MEMSETBADBLOCK`) and redo that partition.
   - A `u-boot` that fails twice is erased completely, so SPL falls back to the new backup.
3. **`kernel`**, then **`rootfs`**, into the inactive slot: the one Linux isn't running from (`d200.slot` in
   `/proc/cmdline`). Never take it from the env's `slot`, which can name a slot that doesn't boot:
   - If the volume is missing, create it (`UBI_IOCMKVOL` on `/dev/ubi0`, with its fixed ID, type and size from
     the layout table); if it is smaller than the image, grow it (`UBI_IOCRSVOL`).
   - A static volume (the kernel) that already holds the image (its data has the image's size and sha256) is left
     alone.
   - `UBI_IOCVOLUP` with the image size on `/dev/ubi0_<id>`, write the image, close, read back and compare
     sha256.
   - A volume that fails twice is truncated (`UBI_IOCVOLUP` with size 0).
   - An interrupted write leaves the volume marked as being updated, and U-Boot won't boot it.
4. **Activate** with one `fw_setenv` call, which is one env write, then reboot:
   ```
   fw_setenv slot <inactive> upgrade_available 1 bootcount 0 ota_result trial
   ```

**Confirm**, at every start of the updater:

| `/proc/cmdline` vs env | What to do |
|---|---|
| `upgrade_available=1`, `d200.slot` = `slot` | Trial boot. Wait up to ~90 s for the key app to be healthy, then `fw_setenv upgrade_available 0 bootcount 0 ota_result ok`. Not healthy: reboot (it counts toward the rollback) |
| `upgrade_available=1`, `d200.slot` ≠ `slot` | U-Boot couldn't boot the new slot: `fw_setenv slot <running> upgrade_available 0 bootcount 0 ota_result failed` |
| `ota_result=rolled-back` | The new slot failed 3 boots. Report it |
| `upgrade_available=0`, `d200.slot` ≠ `slot` | The stable slot didn't boot, and U-Boot fell back to the other one: `fw_setenv slot <running> bootcount 0 ota_result fell-back`. An update repairs the broken slot. An empty env (never updated) is left alone |

**Report:** `ota_result`, the version of each slot, and per target what happened (written, skipped,
retries, blocks marked bad, IDB copies left invalid).

## Power cuts

| During | Result |
|---|---|
| Receiving the bundle | Partial files in `/data/update`, removed at the next boot |
| An IDB copy | That copy is invalid until its magic is written; another copy boots |
| `u-boot-backup` | `u-boot` is still good |
| `u-boot` | Fails SPL's hash check; SPL boots the backup (new and verified) |
| A kernel or rootfs volume | Marked as being updated; the active slot boots |
| Activate, confirm, rollback | One write to the redundant env: the old or the new env, both consistent |
| The trial boot | Counts as a failed boot (limit 3) |
