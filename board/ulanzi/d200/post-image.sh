#!/bin/sh
# Collect the D200 boot images and build the install and update images.
#   idbloader.img   one 256 KiB IDB copy (TPL+SPL) (idb-layout.py)
#   idbloader-x4.img  the "idbloader" partition: 4 copies, at 0x0/0x40000/
#                   0x80000/0xc0000 (the BootROM tries each)
#   u-boot.itb      U-Boot FIT, written to "u-boot" (0x100000) and "u-boot-backup" (0x500000)
#   kernel.itb      kernel FIT image (Image.gz + DTB) for a "kernel_a/b" UBI volume
#   rootfs.ubifs    root filesystem for a "rootfs_a/b" UBI volume (built by Buildroot)
#   ubi.img         the whole "ubi" partition, slot A filled (ubinize.cfg)
#   flash-fastboot.sh     flashes all of the above over USB fastboot
#   d200-full.img   idbloader-x4 + u-boot + u-boot-backup + ubi, for
#                   d200-install.py with rk3308_loader_wo_ftl.bin (from d200-rkbin)
#   d200-install.py writes d200-full.img from maskrom
#   update.tar      the update bundle (docs/ota.md)
#   update.img      the whole install for RKDevTool (rkdevtool-image.py), release
#                   flavour only
# $2: flavour (release or debug, from BR2_ROOTFS_POST_SCRIPT_ARGS)
set -e
FLAVOR="${2:-release}"

# mkimage puts the TPL+SPL right after the header; move it to the second block
# (idempotent, so a rebuild without U-Boot can run this again)
python3 "$(dirname "$0")/idb-layout.py" "$BINARIES_DIR/idbloader.img" "$BINARIES_DIR/idbloader.img.new"
mv "$BINARIES_DIR/idbloader.img.new" "$BINARIES_DIR/idbloader.img"
X4="$BINARIES_DIR/idbloader-x4.img"
head -c 1M /dev/zero | tr '\0' '\377' > "$X4"	# erased flash is 0xff
for i in 0 1 2 3; do
	dd if="$BINARIES_DIR/idbloader.img" of="$X4" bs=256K seek=$i conv=notrunc status=none
done

install -m 0755 "$(dirname "$0")/flash-fastboot.sh" "$(dirname "$0")/d200-install.py" "$BINARIES_DIR/"

if [ -f "$BINARIES_DIR/Image.gz" ]; then
	cp "$(dirname "$0")/kernel.its" "$BINARIES_DIR/"
	# dated like the kernel (external.mk), so it only changes with the kernel
	(cd "$BINARIES_DIR" && SOURCE_DATE_EPOCH=$D200_LINUX_EPOCH "$HOST_DIR/bin/mkimage" -f kernel.its kernel.itb)

	# 128 KiB blocks, 2 KiB pages, no sub-pages
	(cd "$BINARIES_DIR" && "$HOST_DIR/sbin/ubinize" -o ubi.img -p 128KiB -m 2048 -s 2048 \
		"$(dirname "$0")/ubinize.cfg")

	# The start of the NAND as flashed: erased (0xff) padding up to the ubi partition
	FULL="$BINARIES_DIR/d200-full.img"
	head -c 9M /dev/zero | tr '\0' '\377' > "$FULL"
	dd if="$X4" of="$FULL" conv=notrunc status=none
	dd if="$BINARIES_DIR/u-boot.itb" of="$FULL" bs=1M seek=1 conv=notrunc status=none
	dd if="$BINARIES_DIR/u-boot.itb" of="$FULL" bs=1M seek=5 conv=notrunc status=none
	cat "$BINARIES_DIR/ubi.img" >> "$FULL"

	# Update bundle: manifest.json, then the images in write order
	# (target:file, or target:file:optional). MIN_UPDATER and
	# MIN_UPDATER_RELEASE: see docs/ota.md#bundle
	IMAGES="idbloader:idbloader.img u-boot:u-boot.itb kernel:kernel.itb rootfs:rootfs.ubifs"
	MIN_UPDATER=1
	MIN_UPDATER_RELEASE=
	. "$TARGET_DIR/usr/lib/os-release"
	MANIFEST="$BINARIES_DIR/manifest.json"
	{
		printf '{\n  "format": 1,\n  "product": "d200",\n'
		printf '  "flavour": "%s",\n  "version": "%s",\n  "build_id": %s,\n' \
			"$FLAVOR" "$VERSION" "$BUILD_ID"
		printf '  "min_updater": %s,\n' "$MIN_UPDATER"
		[ -z "$MIN_UPDATER_RELEASE" ] ||
			printf '  "min_updater_release": "%s",\n' "$MIN_UPDATER_RELEASE"
		printf '  "images": [\n'
		sep=
		FILES=
		for t in $IMAGES; do
			target=${t%%:*}
			f=${t#*:}
			opt=
			case "$f" in *:optional) f=${f%:optional}; opt=', "optional": true' ;; esac
			FILES="$FILES $f"
			printf '%b    {"target": "%s", "file": "%s", "size": %s, "sha256": "%s"%s}' "$sep" \
				"$target" "$f" "$(stat -c%s "$BINARIES_DIR/$f")" \
				"$(sha256sum "$BINARIES_DIR/$f" | cut -d' ' -f1)" "$opt"
			sep=',\n'
		done
		printf '\n  ]\n}\n'
	} > "$MANIFEST"
	# Signed if D200_SIGNING_KEY holds an Ed25519 private key (PEM): the
	# signature covers manifest.json, and through its hashes the images
	SIG=
	rm -f "$BINARIES_DIR/manifest.sig"
	if [ -n "$D200_SIGNING_KEY" ]; then
		KEY=$(mktemp)
		printf '%s\n' "$D200_SIGNING_KEY" > "$KEY"
		"$HOST_DIR/bin/openssl" pkeyutl -sign -rawin -inkey "$KEY" -in "$MANIFEST" \
			-out "$BINARIES_DIR/manifest.sig"
		rm -f "$KEY"
		SIG=manifest.sig
	fi
	tar -C "$BINARIES_DIR" --owner=0 --group=0 --format=ustar -cf "$BINARIES_DIR/update.tar" \
		manifest.json $SIG $FILES

	rm -f "$BINARIES_DIR/update.img"
	if [ "$FLAVOR" = release ]; then
		python3 "$(dirname "$0")/rkdevtool-image.py" "$BINARIES_DIR/rk3308_loader_wo_ftl.bin" \
			"$BINARIES_DIR" "$VERSION" "$BINARIES_DIR/update.img"
	fi
fi
