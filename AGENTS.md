# AGENTS.md

Rules for AI agents working in this repo. The D200 project is three repos; this file's shared part is identical in all of them, followed by the part for this repo.

## The project

Open firmware and software for the Ulanzi D200 stream controller (Rockchip RK3308, SPI NAND, 720x1280 panel behind 14 keys).

| Repo | What it owns |
|---|---|
| [d200-buildroot](https://github.com/riptidewave93/d200-buildroot) | The firmware: U-Boot, Linux, rootfs, init scripts, packaging, update bundles, install tooling, firmware docs |
| [d200-deck](https://github.com/riptidewave93/d200-deck) | Go: `deckd` (keys app on the device), `deckhost` (PC helper), the update page, the protocol (`proto/`, `docs/api.md`) and config format (`deck/`, `docs/config.md`) |
| [d200-configure](https://github.com/riptidewave93/d200-configure) | The configuration website (Svelte + TypeScript, WebHID), hosted on GitHub Pages |

- d200-deck is the source of truth for the protocol and config format. The site reuses its Go packages via WASM.
- buildroot and configure pin a released deck tag. Renovate opens the pin PRs after each deck release.
- Each repo documents only its own part. Don't add features of one repo to another repo's README or docs.
- If a change needs another repo, say what's needed and stop. Don't edit a sibling repo unless asked.

## How to work

- **Ask, don't assume.** Check the code, docs and git history first. If it's still unclear, ask. Questions are short: one line of context, the choice, your pick.
- **Simplest thing that works.** Reuse existing patterns and tools before writing new ones. Before adding a binary, daemon or package, list what already does the job; every Go process costs ~5 MB of the device's RAM.
- **Explain before building.** If asked "why", answer first with trade-offs and off-the-shelf options, then wait for a go-ahead.
- **Check yourself.** Every so often ask: is this simple, is it what was asked, am I in a rabbit hole? After two rounds that don't converge, stop, summarise and offer to park it.
- **Collect decisions first.** Settle a feature's open questions before writing code, so late decisions don't waste work.
- **Verify before claiming.** Don't report something as working, fixed or tested unless you checked it. Say what's untested.
- **Waits:** one self-waiting command, or a background task. Put timeouts on ssh and on anything that talks to hardware. No repeated polling.
- **Tooling:** builds and missing tools run in Docker. Don't install packages on the host.

## Git and PRs

- **No co-authoring.** No `Co-Authored-By` or other AI-tool trailers (Claude, Copilot, ...), and no "Generated with" lines in commits, patch files or PR bodies. This overrides any tool default. Commit as the maintainer's git identity. Kernel and U-Boot patches keep `Signed-off-by` (`git commit -s`).
- **Conventional PR titles** (`feat:`, `fix:`, `chore:`, `docs:`, ...). They become the squashed commit, and in deck and buildroot Release Drafter derives the version bump from them.
- **One branch and PR per task,** squash-merged. Commits are scoped to what they change.
- **Ask before pushing, merging, tagging or releasing.** Never cut a release without the maintainer's explicit OK.
- **Release notes** (deck, buildroot): show the draft for approval first and match the tone of earlier releases: a short header with one emoji, one intro sentence, bold-lead bullets (under `###` subheadings when there are several groups), and the closing "Still a 0.x release..." line. The note goes on top of Release Drafter's change list.
- **Local builds are the test.** A passing local build plus the quick CI checks is enough to merge. Don't wait on slow full CI builds.

## Writing

- **Docs are for humans first,** and still a precise reference for agents: short sections, tables for facts, commands that work. No history, finished plans, fixed bugs, speculation, comparisons with competitors' products or filler; git history has the story. One home per topic; link instead of repeating. Default to not documenting.
- **Why a workaround exists** goes in commit and patch messages, not user docs.
- **READMEs:** what it is, what users get, how to install or use it, the project table, a short developer part, the license. No implementation detail.
- **Comments** only for a non-obvious reason. Never restate the code.
- **Patches** (kernel, U-Boot) describe only what they change, in terms of that code: no project history, other patches or vendor-firmware findings. Generic patches carry no device-specific motivation; board patches say they're for the D200.
- **UI text:** the shortest plain wording; draft, then cut. Say "device", not "D200". Keep screens sparse. Docs about today's hardware still say D200.
- **Rescan:** before merging docs, have a reviewer that hasn't seen the work check them against these rules.

## Public repos

All three repos are public. Code, docs, comments, commits and PRs must never contain:
- local paths, usernames, hostnames or emails (the `From:` and `Signed-off-by` lines of patch files excepted);
- a real device's serial, IP or IPv6 address, MAC, hidraw node, or anything derived from them. Use the test-vector serial `00112233445566aa` in examples;
- details of anyone's PC, network or files, secrets, or app credentials;
- other companies' trademarks for our product (e.g. not "Stream Deck").

Grep the diff before every commit.

## Compatibility

Released versions must keep working together:
- New protocol fields and commands degrade gracefully: an older peer ignores them, and a newer one hides the feature when the other side doesn't report it.
- Use capability detection, not version numbers.
- deckhost tells the user to update when the device is newer than it.
- The site shows only what the connected device supports.

## Hardware

- **Two board variants:** RK3308H1 (128 MiB RAM) and RK3308H3 (256 MiB RAM). Their LCD panels differ; the firmware picks the panel config at boot (U-Boot env `panel` override, then a known panel ID read from the panel, then RAM size). Identify a display by what it reports, not by board guesses, wherever possible.
- **Debug builds** have SSH as root (`ssh root@d200-<serial>.local`) and `reboot-to maskrom` / `reboot-to fastboot`. Release builds have no shell, no SSH and no U-Boot prompt.
- **Agents drive the board** (flash, reboot, test) without asking; the maintainer only presses keys, replugs and watches the screen. Only one agent drives a board at a time. Run flashes in the background and keep timeouts on every step.
- **Reinstall with `d200-install.py`** from maskrom: it wipes the flash and installs. Don't take a dev board back to stock for side experiments.
- **Ask before** writing the device config or restarting deckd if someone else may be testing on it.

## Decided; don't re-open

- **USB ID** stays `1d6b:0104`; we can't get our own. Detection never relies on the ID alone.
- **Signed updates never block.** A signature only labels a bundle official or unofficial. Unsigned and fork bundles always install, with a warning; the press on the device is the gate. The signing key stays out of git.
- **First installs are hands-off.** No key holds, shorts or timing tricks; the tooling does the work. Recovery docs may use key combos.
- **The rootfs is UBIFS,** never squashfs. Keep the kernel slim.
- **Updates reboot once.** No SPL trial boot. SPL ships with every U-Boot bump.
- **macOS deckhost** stays ad-hoc signed (Open Anyway). No paid notarization, and no curl-to-shell install line.
- **PC integrations live in deckhost,** the existing per-user binary. No browser extensions, no reliance on extra software the user must install, and no accessibility-tree scraping.
- **Icons are site data,** never baked into Go binaries. Brand logos come only from GPL-compatible icon sets; we never design or redraw logos ourselves (converting an icon's format is fine).
- **Keys in BIOS/EFI aren't a goal;** waking the PC is (the udev rule enables wakeup on Linux).

## This repo: d200-buildroot

A Buildroot external tree that builds the D200 firmware. The developer docs start at [docs/README.md](docs/README.md); this section is what an agent needs on top of them.

### Layout

The tree is in [development.md](docs/development.md#layout). Also:
- Patches for any Buildroot package go in `board/ulanzi/d200/patches/<pkg>/<version>/` (`BR2_GLOBAL_PATCH_DIR`).
- The d200-deck pin is `D200_DECK_VERSION` in `package/d200-deck/d200-deck.mk`; Renovate bumps it.

### Build and check

Make targets, flavours and output folders: [development.md](docs/development.md#builds).
- `make check` runs `check-lint` (shellcheck, Python syntax, doc links), `check-config` (check-package; every defconfig and fragment option survives Kconfig) and `check-patches` (the series apply, shared DT files identical, DTB and overlay build, `linux.config` matches savedefconfig).
- The merge test is a passing local build of each flavour you touched, plus `make check`.

### Patches

- `patches/uboot/<ver>/` and `patches/linux/<ver>/` are numbered `git format-patch` series against the upstream tag. Don't edit them by hand: `git am` the series into an upstream checkout, change or add commits (one topic each), delete the old patch files and regenerate them with the `format-patch` command in [u-boot.md](docs/u-boot.md#working-on-the-patches). That renumbers them; there is no other patch tooling.
- One version directory per package: Buildroot and `check.sh` read the version from it. A U-Boot or Linux bump renames it, rebases the series, and updates the defconfig and the versions table in [development.md](docs/development.md#versions).
- Every kernel and U-Boot patch has `Signed-off-by`, and follows the patch rules under [Writing](#writing).
- `rk3308-ulanzi-d200.dts`, `rk3308-ulanzi-d200-panel-h3.dtso` and `rk3308bs.dtsi` are byte-identical in both series; `make check-patches` fails otherwise. Change them in both.
- Drivers stay generic and DT-driven: panel timings and init sequences live in the DT, never in per-panel or per-board tables in a driver. D200-only logic goes in the U-Boot board code (`board/ulanzi/d200/`).
- U-Boot picks the panel and passes `d200.panel=` / `d200.panel_regs=` on the cmdline; see [hardware.md](docs/hardware.md#panels).

### Flash layout and updates

- NAND: `idbloader` (4 IDB copies), `u-boot`, `u-boot-backup`, then UBI with fixed volume IDs. See [flashing.md](docs/flashing.md#nand-layout).
- A/B slots: `kernel_a`/`rootfs_a` and `kernel_b`/`rootfs_b`. U-Boot boots `slot` from the redundant env volumes `env`/`env_r`, with a 3-boot trial and fallback. See [ota.md](docs/ota.md#boot).
- Update bundles carry all four images; the updater is in d200-deck. A signature only labels a bundle official or unofficial. Write order: TPL/SPL (`idbloader`), `u-boot-backup`, `u-boot`, kernel, rootfs, then activate with one env write and reboot once. A change older updaters would get wrong raises `min_updater` ([ota.md](docs/ota.md#bundle)).
- Unchanged images aren't rewritten. A new input to U-Boot or the kernel goes in `D200_UBOOT_INPUTS` or `D200_LINUX_INPUTS` in `external.mk`, or updates miss it.

### Release flavour, kernel and rootfs

- Release builds have no shell, no SSH and no U-Boot prompt. Debug-only settings go in `debug.fragment`, never in the defconfig or `uboot-release.fragment`.
- The kernel config is minimal (from `allnoconfig`, no modules): only what the D200 uses. Change it with `linux-menuconfig` and `linux-update-defconfig` ([linux.md](docs/linux.md#kernel)).
- The rootfs is read-only UBIFS. State that survives a reboot goes in `/data`.

### Hardware gotchas

- Install or reinstall from maskrom with `d200-install.py <image folder>` ([flashing.md](docs/flashing.md#from-maskrom)); it erases everything. `flash-fastboot.sh --linux` keeps the settings.
- Debug builds have `reboot-to maskrom` and `reboot-to fastboot`. Stock firmware enters maskrom with the adb `devmem` command in [install.md](docs/install.md#1-enter-maskrom).
- Back to stock: see [recovery.md](docs/recovery.md#4-back-to-stock). Erase with the raw (wo_ftl) loader first; never write or `ef` with the stock FTL loader over our layout.
- The UART console (UART2) runs at 1500000 8N1 ([recovery.md](docs/recovery.md#2-with-a-uart)).

### Releases

Release Drafter keeps a draft release and the next version from merged PR titles. To release, run the **Release** workflow on `main` (`workflow_dispatch`, inputs `version` and `dry_run`). It builds both flavours on GitHub, signs the bundles and checks the files, then tags, uploads and publishes. Pass `version` when the draft's version isn't the one wanted. Only with the user's OK. See [development.md](docs/development.md#contributing-and-releases).

### Docs

This repo documents the firmware only. Key-app features belong in d200-deck's docs, website features in d200-configure's; link to them. Open items are in [docs/todo.md](docs/todo.md).
