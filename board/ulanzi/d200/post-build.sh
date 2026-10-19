#!/bin/sh
# $1: target dir, $2: flavour (release or debug, from BR2_ROOTFS_POST_SCRIPT_ARGS)
set -e
BOARD_DIR="$(dirname "$0")"
FLAVOR="${2:-release}"

# OS version: the d200-buildroot git tag/commit this image was built from
VERSION=$(git -C "$BR2_EXTERNAL_D200_BUILDROOT_PATH" describe --tags --always --dirty 2>/dev/null || echo dev)
cat > "$TARGET_DIR/usr/lib/os-release" <<EOT
NAME="D200"
ID=d200
PRETTY_NAME="Ulanzi D200 $VERSION ($FLAVOR)"
VERSION="$VERSION"
VERSION_ID="$VERSION"
VARIANT_ID=$FLAVOR
BUILD_ID=$(date -u +%Y%m%d%H%M)
HOME_URL="https://github.com/riptidewave93/d200-buildroot"
EOT

# S30usb-gadget starts radvd with the deck's own prefix
rm -f "$TARGET_DIR/etc/init.d/S50radvd"
# mdnsd installs ssh.service whatever its options say: advertise SSH only
# with an SSH server (debug builds)
[ -e "$TARGET_DIR/usr/sbin/dropbear" ] || rm -f "$TARGET_DIR/etc/mdns.d/ssh.service"
# /data is mounted by S00data. Dropbear (debug builds) keeps its host key there,
# instead of a new one every boot in /var/run (the root is read-only)
mkdir -p "$TARGET_DIR/data"
[ -e "$TARGET_DIR/usr/sbin/dropbear" ] && ln -snf /data/dropbear "$TARGET_DIR/etc/dropbear"
# The toolchain always installs libstdc++ (2.4 MB), libgomp and libatomic:
# drop each unless something in the image links it
NEEDED=$(find "$TARGET_DIR" -type f -exec "$HOST_DIR/bin/aarch64-linux-readelf" -d {} + 2>/dev/null |
	grep 'NEEDED')
for lib in libstdc++ libgomp libatomic; do
	echo "$NEEDED" | grep -qF "[$lib.so" || rm -f "$TARGET_DIR/usr/lib/$lib.so"*
done

# The read-only USB drive image (mass storage gadget) from usb-drive/: the
# README gets the version, and its debug section only in debug builds.
# S30usb-gadget fills in the D200's name and addresses at boot, from
# usb-drive-readme.md into the README's bytes at usb-drive-readme.at
SHARE="$TARGET_DIR/usr/share/d200"
IMG="$SHARE/usb-drive.img"
DRIVE=$(mktemp -d)
cp -r "$BOARD_DIR"/usb-drive/. "$DRIVE"/
sed -i -e "s/@VERSION@/$VERSION/" -e "s/@FLAVOR@/$FLAVOR/" "$DRIVE/README.md"
[ "$FLAVOR" = debug ] || sed -i '/^## Debug build/,$d' "$DRIVE/README.md"
mkdir -p "$SHARE"
mv "$DRIVE/README.md" "$SHARE/usb-drive-readme.md"
python3 "$BOARD_DIR/usb-drive-readme.py" pad "$SHARE/usb-drive-readme.md" "$DRIVE/README.md"
rm -f "$IMG"
"$HOST_DIR/sbin/mkfs.vfat" -C -n "D200 DECK" "$IMG" 1024 >/dev/null
"$HOST_DIR/bin/mcopy" -i "$IMG" "$DRIVE"/* ::/
python3 "$BOARD_DIR/usb-drive-readme.py" locate "$IMG" "$DRIVE/README.md" > "$SHARE/usb-drive-readme.at"
rm -rf "$DRIVE"
