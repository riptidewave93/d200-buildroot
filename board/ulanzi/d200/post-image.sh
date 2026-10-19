#!/bin/sh
# Collect the D200 boot images and build a USB loader for rkdeveloptool.
#   idbloader.img   TPL+SPL, written 4x to SPI NAND 0x0/0x40000/0x80000/0xc0000
#   u-boot.itb      U-Boot FIT, written to "u-boot" (0x100000) and "u-boot-backup" (0x500000)
#   d200-usb-loader.bin   for `rkdeveloptool boot` from maskrom (runs U-Boot from RAM)
#   kernel.itb      kernel FIT image (Image.gz + DTB) for the "kernel" UBI volume
#   rootfs.ubifs    root filesystem for the "rootfs" UBI volume (built by Buildroot)
#   ubi.img         the whole "ubi" partition: kernel + rootfs volumes (ubinize.cfg)
#   flash-fastboot.sh     flashes all of the above over USB fastboot
#   d200-full.img   idbloader x4 + u-boot + u-boot-backup + ubi, for
#                   rkdeveloptool with rk3308_loader_wo_ftl.bin (from d200-rkbin)
set -e

INI="$BINARIES_DIR/d200-usb-loader.ini"
cat > "$INI" <<INI
[CHIP_NAME]
NAME=RK3308
[VERSION]
MAJOR=1
MINOR=0
[CODE471_OPTION]
NUM=1
Path1=$BINARIES_DIR/u-boot-rockchip-usb471.bin
Sleep=1
[CODE472_OPTION]
NUM=1
Path1=$BINARIES_DIR/u-boot-rockchip-usb472.bin
[LOADER_OPTION]
NUM=2
LOADER1=FlashData
LOADER2=FlashBoot
FlashData=$BINARIES_DIR/u-boot-rockchip-usb471.bin
FlashBoot=$BINARIES_DIR/u-boot-rockchip-usb472.bin
[OUTPUT]
PATH=$BINARIES_DIR/d200-usb-loader.bin
INI

"$HOST_DIR/bin/boot_merger" "$INI"
rm -f "$INI"

install -m 0755 "$(dirname "$0")/flash-fastboot.sh" "$BINARIES_DIR/"

if [ -f "$BINARIES_DIR/Image.gz" ]; then
	cp "$(dirname "$0")/kernel.its" "$BINARIES_DIR/"
	(cd "$BINARIES_DIR" && "$HOST_DIR/bin/mkimage" -f kernel.its kernel.itb)

	# 128 KiB blocks, 2 KiB pages, no sub-pages
	(cd "$BINARIES_DIR" && "$HOST_DIR/sbin/ubinize" -o ubi.img -p 128KiB -m 2048 -s 2048 \
		"$(dirname "$0")/ubinize.cfg")

	# The start of the NAND as flashed: erased (0xff) padding up to the ubi partition
	FULL="$BINARIES_DIR/d200-full.img"
	head -c 9M /dev/zero | tr '\0' '\377' > "$FULL"
	for i in 0 1 2 3; do
		dd if="$BINARIES_DIR/idbloader.img" of="$FULL" bs=256K seek=$i conv=notrunc status=none
	done
	dd if="$BINARIES_DIR/u-boot.itb" of="$FULL" bs=1M seek=1 conv=notrunc status=none
	dd if="$BINARIES_DIR/u-boot.itb" of="$FULL" bs=1M seek=5 conv=notrunc status=none
	cat "$BINARIES_DIR/ubi.img" >> "$FULL"
fi
