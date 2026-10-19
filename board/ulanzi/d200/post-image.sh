#!/bin/sh
# Collect the D200 boot images and build a USB loader for rkdeveloptool.
#   idbloader.img   one 256 KiB IDB copy (TPL+SPL), written 4x to SPI NAND
#                   0x0/0x40000/0x80000/0xc0000 (idb-layout.py)
#   u-boot.itb      U-Boot FIT, written to "u-boot" (0x100000) and "u-boot-backup" (0x500000)
#   d200-usb-loader.bin   for `rkdeveloptool boot` from maskrom (runs U-Boot from RAM)
#   kernel.itb      kernel FIT image (Image.gz + DTB) for a "kernel_a/b" UBI volume
#   rootfs.ubifs    root filesystem for a "rootfs_a/b" UBI volume (built by Buildroot)
#   ubi.img         the whole "ubi" partition, slot A filled (ubinize.cfg)
#   flash-fastboot.sh     flashes all of the above over USB fastboot
#   d200-full.img   idbloader x4 + u-boot + u-boot-backup + ubi, for
#                   rkdeveloptool with rk3308_loader_wo_ftl.bin (from d200-rkbin)
#   update.tar      the update bundle (docs/ota.md)
# $2: flavour (release or debug, from BR2_ROOTFS_POST_SCRIPT_ARGS)
set -e
FLAVOR="${2:-release}"

# mkimage puts the TPL+SPL right after the header; move it to the second block
# (idempotent, so a rebuild without U-Boot can run this again)
python3 "$(dirname "$0")/idb-layout.py" "$BINARIES_DIR/idbloader.img" "$BINARIES_DIR/idbloader.img.new"
mv "$BINARIES_DIR/idbloader.img.new" "$BINARIES_DIR/idbloader.img"

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

	# Update bundle: manifest.json, then the images in write order
	. "$TARGET_DIR/usr/lib/os-release"
	MANIFEST="$BINARIES_DIR/manifest.json"
	{
		printf '{\n  "format": 1,\n  "product": "d200",\n'
		printf '  "flavour": "%s",\n  "version": "%s",\n  "build_id": %s,\n' \
			"$FLAVOR" "$VERSION" "$BUILD_ID"
		printf '  "images": [\n'
		sep=
		for t in idbloader:idbloader.img u-boot:u-boot.itb kernel:kernel.itb rootfs:rootfs.ubifs; do
			f=${t#*:}
			printf '%b    {"target": "%s", "file": "%s", "size": %s, "sha256": "%s"}' "$sep" \
				"${t%%:*}" "$f" "$(stat -c%s "$BINARIES_DIR/$f")" \
				"$(sha256sum "$BINARIES_DIR/$f" | cut -d' ' -f1)"
			sep=',\n'
		done
		printf '\n  ]\n}\n'
	} > "$MANIFEST"
	tar -C "$BINARIES_DIR" --owner=0 --group=0 --format=ustar -cf "$BINARIES_DIR/update.tar" \
		manifest.json idbloader.img u-boot.itb kernel.itb rootfs.ubifs
fi
