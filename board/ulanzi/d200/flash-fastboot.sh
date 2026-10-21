#!/bin/sh
# Flash a Ulanzi D200 over USB fastboot.
#
# Get the board into fastboot first: "reboot-to fastboot" on it, hold the
# top-left key ("Hold for Fastboot") while it boots, or run "fastboot usb 0"
# on the U-Boot console (debug builds).
#
#   flash-fastboot.sh [options] [image-dir]
#     image-dir       holds the images (default: the script's directory, or
#                     its build/ subdirectory)
#     (no option)     full install: U-Boot + the whole UBI partition from
#                     ubi.img (slot A filled, slot B empty). The U-Boot
#                     environment, /data and any splash are reset.
#     --uboot         update only U-Boot (idbloader-x4.img, u-boot.itb)
#     --linux         update only Linux: kernel.itb and rootfs.ubifs into slot A
#                     (kernel_a, rootfs_a), and boot slot A; /data and the
#                     splash are kept
#     --splash <bmp>  also put a boot splash in the "splash" UBI volume
#     --no-reboot     stay in fastboot when done
#
set -e
# UBI volume sizes for --linux, when the volumes don't exist yet (as in ubinize.cfg)
KERNEL_VOL_SIZE=0x800000
ROOTFS_VOL_SIZE=0x2000000

MODE=full; SPLASH=; REBOOT=1; DIR=
while [ $# -gt 0 ]; do
	case "$1" in
	--uboot) MODE=uboot ;;
	--linux) MODE=linux ;;
	--splash) SPLASH=$2; shift ;;
	--no-reboot) REBOOT= ;;
	-h|--help) sed -n '2,21p' "$0"; exit 0 ;;
	*) DIR=$1 ;;
	esac
	shift
done
if [ -z "$DIR" ]; then
	DIR=$(dirname "$0")
	[ -f "$DIR/u-boot.itb" ] || DIR=$DIR/build
fi

case $MODE in
full)	FILES="idbloader-x4.img u-boot.itb ubi.img" ;;
uboot)	FILES="idbloader-x4.img u-boot.itb" ;;
linux)	FILES="kernel.itb rootfs.ubifs" ;;
esac
for f in $FILES; do
	[ -f "$DIR/$f" ] || { echo "missing $DIR/$f" >&2; exit 1; }
done
[ -z "$SPLASH" ] || [ -f "$SPLASH" ] || { echo "missing $SPLASH" >&2; exit 1; }

fb() {
	out=$(fastboot "$@" 2>&1) || { echo "$out" >&2; exit 1; }
	echo "$out" | grep -v '^Finished' || true
}
getvar() {
	fastboot getvar "$1" 2>&1 | sed -n "s/^$1: //p"
}
# size of a file in bytes (wc -c, as macOS has no GNU stat)
file_size() {
	echo $(($(wc -c <"$1")))
}
# size of a partition or UBI volume in bytes, empty if it doesn't exist
part_size() {
	getvar "partition-size:$1"
}
# (re)create UBI volume $1 ($3 = dynamic/static) so it holds at least $2 bytes
ensure_vol() {
	have=$(part_size "$1")
	if [ -n "$have" ] && [ $((have)) -ge $(($2)) ]; then
		return
	fi
	fb oem run:ubi part ubi
	[ -n "$have" ] && fb oem run:ubi remove "$1"
	fb oem run:ubi create "$1" "$(printf 0x%x $(($2)))" "$3"
}

# make sure this is a D200 running our U-Boot (it has an idbloader partition)
[ -n "$(part_size idbloader)" ] || { echo "no D200 in fastboot mode found" >&2; exit 1; }
echo "D200 serial: $(getvar serialno)"

# no sparse images: everything must fit the download buffer
max=$(getvar max-download-size)
for f in $FILES; do
	[ "$(file_size "$DIR/$f")" -le $((max)) ] ||
		{ echo "$f is larger than the $((max)) byte download buffer" >&2; exit 1; }
done

if [ $MODE != linux ]; then
	fb flash u-boot "$DIR/u-boot.itb"
	fb flash u-boot-backup "$DIR/u-boot.itb"
	fb flash idbloader "$DIR/idbloader-x4.img"
fi

case $MODE in
full)
	fb flash ubi "$DIR/ubi.img"
	;;
linux)
	ensure_vol kernel_a "$KERNEL_VOL_SIZE" static
	ensure_vol rootfs_a "$ROOTFS_VOL_SIZE" dynamic
	fb flash kernel_a "$DIR/kernel.itb"
	fb flash rootfs_a "$DIR/rootfs.ubifs"
	fb oem "run:setenv slot a; setenv upgrade_available 0; setenv bootcount 0; saveenv"
	;;
esac

if [ -n "$SPLASH" ]; then
	# recreate the volume at the image size, so any size fits
	fb oem run:ubi part ubi
	[ -n "$(part_size splash)" ] && fb oem run:ubi remove splash
	fb oem run:ubi create splash "$(printf 0x%x "$(file_size "$SPLASH")")" static 7
	fb flash splash "$SPLASH"
fi

if [ -n "$REBOOT" ]; then
	fb reboot
fi
echo "done"
